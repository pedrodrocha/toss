---@class TossOk<T>
---@field kind "ok"
---@field value T
---@field is_ok fun(self: TossOk<T>): boolean
---@field is_err fun(self: TossOk<T>): boolean

---@class TossErr
---@field kind "err"
---@field error TossError
---@field is_ok fun(self: TossErr): boolean
---@field is_err fun(self: TossErr): boolean

---@alias TossResult<T> TossOk<T>|TossErr

---@class TossResultModule
---@field ok fun(value: any|nil): TossOk<any>
---@field err fun(error_value: TossError): TossErr
---@field is fun(value: any): boolean

local M = {}

local result_methods = {}

---@param self TossResult<any>
---@return boolean
function result_methods.is_ok(self)
  return self.kind == "ok"
end

---@param self TossResult<any>
---@return boolean
function result_methods.is_err(self)
  return self.kind == "err"
end

local result_metatable = {
  __index = result_methods,
}

---@generic T
---@param value T|nil
---@return TossOk<T>
function M.ok(value)
  return setmetatable({
    kind = "ok",
    value = value,
  }, result_metatable)
end

---@param error_value TossError
---@return TossErr
function M.err(error_value)
  return setmetatable({
    kind = "err",
    error = error_value,
  }, result_metatable)
end

---@param value any
---@return boolean
function M.is(value)
  return type(value) == "table" and (value.kind == "ok" or value.kind == "err")
end

return M
