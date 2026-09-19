---@class TossFileBufferContextModule
---@field capture fun(): TossResult<TossFileContext>

local errors = require("toss.errors")
local path = require("toss.context.path")
local result = require("toss.result")
local M = {}

---@return TossResult<nil>
local function assert_buffer_is_file()
  if vim.bo.buftype ~= "" then
    return result.err(errors.buffer_not_file())
  end

  return result.ok()
end

---@param absolute_path string
---@return TossResult<nil>
local function validate_file_path(absolute_path)
  if absolute_path == "" then
    return result.err(errors.buffer_without_path())
  end

  return result.ok()
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

---@return TossResult<TossFileContext>
function M.capture()
  local buffer_result = assert_buffer_is_file()
  if buffer_result:is_err() then
    return buffer_result
  end

  local absolute_path = vim.api.nvim_buf_get_name(0)
  local path_result = validate_file_path(absolute_path)
  if path_result:is_err() then
    return path_result
  end

  local resolved_path = path.relative_or_absolute(absolute_path, 0)
  local start_line, end_line

  if is_visual_mode() then
    start_line, end_line = visual_range()
  end

  return result.ok({
    kind = "file",
    path = resolved_path,
    start_line = start_line,
    end_line = end_line,
  })
end

return M
