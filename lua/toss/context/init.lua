---@class TossFileContext
---@field path string
---@field start_line integer|nil
---@field end_line integer|nil

---@class TossTextContext
---@field text string

---@alias TossContext TossFileContext|TossTextContext

---@alias TossContextMode "file"|"yank"

---@class TossContextModule
---@field capture fun(mode: TossContextMode|nil): TossResult<TossContext>

local errors = require("toss.errors")
local register_context = require("toss.context.register")
local result = require("toss.result")
local M = {}
local project_root = require("toss.context.root")

---@param error_value TossError
---@return TossErr
local function invalid(error_value)
  return result.err(error_value)
end

---@return TossResult<nil>
local function assert_buffer_is_file()
  if vim.bo.buftype ~= "" then
    return invalid(errors.buffer_not_file())
  end

  return result.ok()
end

---@param absolute_path string
---@return TossResult<nil>
local function validate_file_path(absolute_path)
  if absolute_path == "" then
    return invalid(errors.buffer_without_path())
  end

  return result.ok()
end

---@param root string|nil
---@param absolute_path string
---@return string
local function resolve_path(root, absolute_path)
  local relative_path = root and vim.fs.relpath(root, absolute_path)
  if relative_path and relative_path ~= "" then
    return relative_path
  end

  return absolute_path
end

---@return boolean
local function is_visual_mode()
  local mode = vim.api.nvim_get_mode().mode
  return mode == "v" or mode == "V" or mode == "\022"
end

---@return integer, integer
local function visual_range()
  local visual_start = vim.fn.getpos("v")
  local visual_end = vim.fn.getpos(".")

  return math.min(visual_start[2], visual_end[2]), math.max(visual_start[2], visual_end[2])
end

---@return TossResult<TossContext>
local function capture_from_file()
  local buffer_result = assert_buffer_is_file()
  if buffer_result.kind == "err" then
    return buffer_result
  end

  local absolute_path = vim.api.nvim_buf_get_name(0)
  local path_result = validate_file_path(absolute_path)
  if path_result.kind == "err" then
    return path_result
  end

  local root = project_root.resolve(0)
  local path = resolve_path(root, absolute_path)
  local start_line, end_line

  if is_visual_mode() then
    start_line, end_line = visual_range()
  end

  return result.ok({
    path = path,
    start_line = start_line,
    end_line = end_line,
  })
end

---@return TossResult<TossContext>
local function capture_from_yank()
  local register_result = register_context.current()
  if register_result.kind == "err" then
    return register_result
  end

  local register = register_result.value
  if register.path ~= nil and register.start_line ~= nil and register.end_line ~= nil then
    return result.ok({
      path = register.path,
      start_line = register.start_line,
      end_line = register.end_line,
    })
  end

  return result.ok({ text = register.text })
end

---@param mode TossContextMode|nil
---@return TossResult<TossContext>
function M.capture(mode)
  if mode == "yank" then
    return capture_from_yank()
  end

  return capture_from_file()
end

return M
