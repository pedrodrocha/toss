---@class TossYankRecord
---@field text string
---@field register_type string
---@field path string|nil
---@field start_line integer|nil
---@field end_line integer|nil

---@class TossYankObserverModule
---@field setup fun(): TossResult<nil>
---@field current fun(): TossResult<TossYankRecord>

local errors = require("toss.errors")
local project_root = require("toss.context.root")
local result = require("toss.result")

local M = {}

local autocmd_group = "TossRegisterContext"

-- The observer is a singleton: Neovim has one unnamed register for this
-- plugin instance, so one state table is enough for the latest record.
local state = {
  last_record = nil,
}

-- These operators write source information that can be useful for a yank toss.
local tracked_operators = {
  y = true,
  d = true,
  c = true,
}

-- These registers do not update the unnamed register when explicitly used.
local non_unnamed_registers = {
  ["_"] = true,
  ["+"] = true,
  ["*"] = true,
}

-- Register access ----------------------------------------------------------

---@return TossResult<{ text: string, register_type: string }>
local function read_unnamed_register()
  if type(vim) ~= "table" or type(vim.fn) ~= "table" then
    return result.err(errors.register_unavailable())
  end

  if type(vim.fn.getreg) ~= "function" or type(vim.fn.getregtype) ~= "function" then
    return result.err(errors.register_unavailable())
  end

  local read_text, text = pcall(vim.fn.getreg, '"')
  if not read_text then
    return result.err(errors.register_read("could not read the unnamed register", text))
  end

  local read_type, register_type = pcall(vim.fn.getregtype, '"')
  if not read_type then
    return result.err(errors.register_read("could not read the unnamed register type", register_type))
  end

  if type(text) ~= "string" or type(register_type) ~= "string" then
    return result.err(errors.register_read("Neovim returned an invalid unnamed register"))
  end

  return result.ok({
    text = text,
    register_type = register_type,
  })
end

-- Source metadata recovery -------------------------------------------------

---@param value any
---@return boolean
local function is_positive_integer(value)
  return type(value) == "number" and value >= 1 and value % 1 == 0
end

---@param bufnr integer
---@return string|nil
local function recover_source_path(bufnr)
  if type(vim) ~= "table" or type(vim.api) ~= "table" or type(vim.api.nvim_buf_get_name) ~= "function" then
    return nil
  end

  local has_file_buffer, buftype = pcall(function()
    return vim.bo[bufnr].buftype
  end)
  if not has_file_buffer or buftype ~= "" then
    return nil
  end

  local got_name, absolute_path = pcall(vim.api.nvim_buf_get_name, bufnr)
  if not got_name or type(absolute_path) ~= "string" or absolute_path == "" then
    return nil
  end

  local got_root, root = pcall(project_root.resolve, bufnr)
  if got_root and root and type(vim.fs) == "table" and type(vim.fs.relpath) == "function" then
    local got_relative, relative_path = pcall(vim.fs.relpath, root, absolute_path)
    if got_relative and type(relative_path) == "string" and relative_path ~= "" then
      return relative_path
    end
  end

  return absolute_path
end

---@return integer|nil, integer|nil
local function recover_operation_range()
  if type(vim) ~= "table" or type(vim.fn) ~= "table" or type(vim.fn.getpos) ~= "function" then
    return nil, nil
  end

  local got_start, start_position = pcall(vim.fn.getpos, "'[")
  local got_end, end_position = pcall(vim.fn.getpos, "']")
  if not got_start or not got_end or type(start_position) ~= "table" or type(end_position) ~= "table" then
    return nil, nil
  end

  local start_line = start_position[2]
  local end_line = end_position[2]
  if not is_positive_integer(start_line) or not is_positive_integer(end_line) then
    return nil, nil
  end

  return math.min(start_line, end_line), math.max(start_line, end_line)
end

---@param bufnr integer|nil
---@return string|nil, integer|nil, integer|nil
local function recover_source_metadata(bufnr)
  if type(bufnr) ~= "number" then
    return nil, nil, nil
  end

  local path = recover_source_path(bufnr)
  local start_line, end_line = recover_operation_range()

  -- A path without a reliable operation range is not enough to produce a
  -- file reference. Treat it as literal text instead of guessing.
  if path == nil or start_line == nil or end_line == nil then
    return nil, nil, nil
  end

  return path, start_line, end_line
end

-- Event filtering and record storage --------------------------------------

---@param event table|nil
---@return boolean
local function is_tracked_yank_event(event)
  if type(event) ~= "table" or not tracked_operators[event.operator] then
    return false
  end

  local register_name = event.regname or ""
  return not non_unnamed_registers[register_name]
end

---@param register { text: string, register_type: string }
---@param path string|nil
---@param start_line integer|nil
---@param end_line integer|nil
local function store_latest_record(register, path, start_line, end_line)
  state.last_record = {
    text = register.text,
    register_type = register.register_type,
    path = path,
    start_line = start_line,
    end_line = end_line,
  }
end

---@param event table|nil
---@param bufnr integer|nil
---@return TossResult<boolean>
local function record_tracked_yank(event, bufnr)
  if not is_tracked_yank_event(event) then
    return result.ok(false)
  end

  local register_result = read_unnamed_register()
  if register_result:is_err() then
    return result.err(register_result.error)
  end

  local path, start_line, end_line = recover_source_metadata(bufnr)
  store_latest_record(register_result.value, path, start_line, end_line)

  return result.ok(true)
end

-- Current-register matching and fallback ----------------------------------

---@param register { text: string, register_type: string }
---@param record TossYankRecord|nil
---@return boolean
local function register_matches_record(register, record)
  return record ~= nil and register.text == record.text and register.register_type == record.register_type
end

---@param register { text: string, register_type: string }
---@return TossYankRecord
local function make_literal_record(register)
  return {
    text = register.text,
    register_type = register.register_type,
    path = nil,
    start_line = nil,
    end_line = nil,
  }
end

---@param register { text: string, register_type: string }
---@return TossYankRecord
local function current_register_record(register)
  if not register_matches_record(register, state.last_record) then
    -- Without matching source metadata, the explicit register toss is literal.
    return make_literal_record(register)
  end

  return {
    text = register.text,
    register_type = register.register_type,
    path = state.last_record.path,
    start_line = state.last_record.start_line,
    end_line = state.last_record.end_line,
  }
end

-- TextYankPost observer lifecycle -----------------------------------------

---@param args table|nil
local function on_text_yank_post(args)
  local event = type(vim) == "table" and type(vim.v) == "table" and vim.v.event or nil
  local bufnr = type(args) == "table" and args.buf

  -- A failed observation should not interrupt the yank/delete/change that
  -- caused it. The next toss will use the last valid record, if any.
  pcall(record_tracked_yank, event, bufnr)
end

---@param group any
---@return boolean, any
local function install_text_yank_observer(group)
  return pcall(vim.api.nvim_create_autocmd, "TextYankPost", {
    group = group,
    callback = on_text_yank_post,
  })
end

-- Public observer operations ----------------------------------------------

---@return TossResult<TossYankRecord>
function M.current()
  local register_result = read_unnamed_register()
  if register_result:is_err() then
    return result.err(register_result.error)
  end

  return result.ok(current_register_record(register_result.value))
end

---@return TossResult<nil>
function M.setup()
  if
    type(vim) ~= "table"
    or type(vim.api) ~= "table"
    or type(vim.api.nvim_create_augroup) ~= "function"
    or type(vim.api.nvim_create_autocmd) ~= "function"
  then
    return result.err(errors.register_setup("Neovim autocmd API is unavailable"))
  end

  local created, group = pcall(vim.api.nvim_create_augroup, autocmd_group, { clear = true })
  if not created then
    return result.err(errors.register_setup("could not create TextYankPost autocmd group", group))
  end

  local registered, registration_error = install_text_yank_observer(group)
  if not registered then
    return result.err(errors.register_setup("could not register TextYankPost autocmd", registration_error))
  end

  return result.ok()
end

return M
