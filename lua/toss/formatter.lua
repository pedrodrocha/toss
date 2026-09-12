---@class TossFormatter
---@field format fun(ctx: TossContext|nil): TossResult<string>

local errors = require("toss.errors")
local result = require("toss.result")
local M = {}

---@param error_value TossError
---@return TossErr
local function invalid(error_value)
  return result.err(error_value)
end

---@param value any
---@return boolean
local function is_positive_integer(value)
  return type(value) == "number" and value >= 1 and value % 1 == 0
end

---@param ctx TossContext|nil
---@return TossResult<string>
function M.format(ctx)
  if type(ctx) ~= "table" then
    return invalid(errors.invalid_context())
  end

  if ctx.path == nil then
    if type(ctx.text) ~= "string" or ctx.text == "" then
      return invalid(errors.invalid_context_text())
    end

    return result.ok(ctx.text)
  end

  if type(ctx.path) ~= "string" or ctx.path == "" then
    return invalid(errors.invalid_context_path())
  end

  local start_line = ctx.start_line
  local end_line = ctx.end_line

  if start_line == nil and end_line == nil then
    return result.ok("@" .. ctx.path)
  end

  if start_line == nil or end_line == nil then
    return invalid(errors.context_range("context range must include start_line and end_line"))
  end

  if not is_positive_integer(start_line) or not is_positive_integer(end_line) then
    return invalid(errors.context_range("context range lines must be positive integers"))
  end

  if start_line > end_line then
    return invalid(errors.context_range("context range start_line must not exceed end_line"))
  end

  return result.ok(string.format("@%s#L%d-L%d", ctx.path, start_line, end_line))
end

return M
