---@class TossFileContext
---@field path string
---@field start_line integer|nil
---@field end_line integer|nil

---@class TossTextContext
---@field text string

---@alias TossContext TossFileContext|TossTextContext

---@alias TossOrigin "file_buffer"|"yank"

---@class TossContextModule
---@field capture fun(origin: TossOrigin|nil): TossResult<TossContext>

local errors = require("toss.errors")
local file_buffer = require("toss.context.file_buffer")
local register_context = require("toss.context.register")
local result = require("toss.result")
local M = {}

---@return TossResult<TossContext>
local function capture_from_yank()
  local register_result = register_context.current()
  if register_result:is_err() then
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

---@param origin TossOrigin|nil
---@return TossResult<TossContext>
function M.capture(origin)
  if origin == nil or origin == "file_buffer" then
    return file_buffer.capture()
  end

  if origin == "yank" then
    return capture_from_yank()
  end

  return result.err(errors.invalid_context_origin(origin))
end

return M
