local errors = require("toss.errors")
local herdr = require("toss.transports.herdr")
local result = require("toss.result")

---@type table<string, TossTransport>
local registry = {
  herdr = herdr,
}

---@type string[]
local priorities = {
  "herdr",
}

---@class TossTransports
---@field registry table<string, TossTransport>
---@field priorities string[]
---@field resolve fun(name: string): TossResult<TossTransport>

local M = {
  registry = registry,
  priorities = priorities,
}

---@param transport TossTransport|nil
---@return boolean
local function is_available(transport)
  if type(transport) ~= "table" or type(transport.available) ~= "function" then
    return false
  end

  local ok, available = pcall(transport.available)
  return ok and available == true
end

---@param name string
---@return TossTransport|nil
local function registered_transport(name)
  for _, transport_name in ipairs(M.priorities) do
    if transport_name == name then
      return M.registry[name]
    end
  end

  return nil
end

---@param name string
---@return TossResult<TossTransport>
function M.resolve(name)
  if name == "auto" then
    for _, transport_name in ipairs(M.priorities) do
      local transport = registered_transport(transport_name)
      if is_available(transport) then
        return result.ok(transport)
      end
    end

    return result.err(errors.no_transport())
  end

  local transport = registered_transport(name)
  if type(transport) ~= "table" then
    return result.err(errors.unknown_transport(name))
  end

  return result.ok(transport)
end

return M
