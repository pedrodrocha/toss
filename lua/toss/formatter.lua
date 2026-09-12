---@class TossFormatter
---@field format fun(ctx: TossContext|nil): string|nil, string|nil

---@type TossFormatter
local M = {}

---@param message string
---@return nil, string
local function invalid(message)
  return nil, message
end

---@param value any
---@return boolean
local function is_positive_integer(value)
  return type(value) == "number" and value >= 1 and value % 1 == 0
end

---@param ctx TossContext|nil
---@return string|nil, string|nil
function M.format(ctx)
  if type(ctx) ~= "table" then
    return invalid("context must be a table")
  end

  if type(ctx.path) ~= "string" or ctx.path == "" then
    return invalid("context path must be a non-empty string")
  end

  local start_line = ctx.start_line
  local end_line = ctx.end_line

  if start_line == nil and end_line == nil then
    return "@" .. ctx.path
  end

  if start_line == nil or end_line == nil then
    return invalid("context range must include start_line and end_line")
  end

  if not is_positive_integer(start_line) or not is_positive_integer(end_line) then
    return invalid("context range lines must be positive integers")
  end

  if start_line > end_line then
    return invalid("context range start_line must not exceed end_line")
  end

  return string.format("@%s#L%d-L%d", ctx.path, start_line, end_line)
end

return M
