---@class TossRegisterRecord
---@field text string
---@field register_type string
---@field path string|nil
---@field start_line integer|nil
---@field end_line integer|nil

---@class TossRegisterContextModule
---@field setup fun(): TossResult<nil>
---@field current fun(): TossResult<TossRegisterRecord>

local errors = require("toss.errors")
local project_root = require("toss.context.root")
local result = require("toss.result")

local M = {}

local autocmd_group = "TossRegisterContext"
local last_record

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

---@param value any
---@return boolean
local function is_positive_integer(value)
  return type(value) == "number" and value >= 1 and value % 1 == 0
end

---@return TossResult<{ text: string, register_type: string }>
local function read_register()
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

---@param bufnr integer
---@return string|nil
local function source_path(bufnr)
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
local function operation_range()
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

---@param event table|nil
---@return boolean
local function should_record(event)
  if type(event) ~= "table" or not tracked_operators[event.operator] then
    return false
  end

  local register_name = event.regname or ""
  return not non_unnamed_registers[register_name]
end

---@param event table|nil
---@param bufnr integer|nil
---@return TossResult<boolean>
local function record(event, bufnr)
  if not should_record(event) then
    return result.ok(false)
  end

  local register_result = read_register()
  if register_result:is_err() then
    return result.err(register_result.error)
  end

  local source_path_value
  local start_line
  local end_line
  if type(bufnr) == "number" then
    source_path_value = source_path(bufnr)
    start_line, end_line = operation_range()

    -- A path without a reliable operation range is not enough to produce a
    -- file reference. Treat it as literal text instead of guessing.
    if source_path_value == nil or start_line == nil or end_line == nil then
      source_path_value = nil
      start_line = nil
      end_line = nil
    end
  end

  last_record = {
    text = register_result.value.text,
    register_type = register_result.value.register_type,
    path = source_path_value,
    start_line = start_line,
    end_line = end_line,
  }

  return result.ok(true)
end

---@return TossResult<TossRegisterRecord>
function M.current()
  local register_result = read_register()
  if register_result:is_err() then
    return result.err(register_result.error)
  end

  local current_register = register_result.value
  local matches_record = last_record ~= nil
    and current_register.text == last_record.text
    and current_register.register_type == last_record.register_type

  if matches_record then
    return result.ok({
      text = current_register.text,
      register_type = current_register.register_type,
      path = last_record.path,
      start_line = last_record.start_line,
      end_line = last_record.end_line,
    })
  end

  -- Without matching source metadata, the explicit register toss is literal.
  return result.ok({
    text = current_register.text,
    register_type = current_register.register_type,
    path = nil,
    start_line = nil,
    end_line = nil,
  })
end

---@return TossResult<nil>
function M.setup()
  local created, group = pcall(vim.api.nvim_create_augroup, autocmd_group, { clear = true })
  if not created then
    return result.err(errors.register_setup("could not create TextYankPost autocmd group", group))
  end

  local registered, registration_error = pcall(vim.api.nvim_create_autocmd, "TextYankPost", {
    group = group,
    callback = function(args)
      local event = type(vim) == "table" and vim.v and vim.v.event
      local bufnr = type(args) == "table" and args.buf
      -- A failed observation should not interrupt the yank/delete/change that
      -- caused it. The next toss will use the last valid record, if any.
      pcall(record, event, bufnr)
    end,
  })
  if not registered then
    return result.err(errors.register_setup("could not register TextYankPost autocmd", registration_error))
  end

  return result.ok()
end

return M
