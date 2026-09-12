---@class TossOk<T>
---@field kind "ok"
---@field value T

---@class TossErr
---@field kind "err"
---@field error TossError

---@alias TossResult<T> TossOk<T>|TossErr

---@class TossResultModule
---@field ok fun(value: any|nil): TossOk<any>
---@field err fun(error_value: TossError): TossErr
---@field is fun(value: any): boolean

local M = {}

---@generic T
---@param value T|nil
---@return TossOk<T>
function M.ok(value)
  return {
    kind = "ok",
    value = value,
  }
end

---@param error_value TossError
---@return TossErr
function M.err(error_value)
  return {
    kind = "err",
    error = error_value,
  }
end

---@param value any
---@return boolean
function M.is(value)
  return type(value) == "table" and (value.kind == "ok" or value.kind == "err")
end

return M
