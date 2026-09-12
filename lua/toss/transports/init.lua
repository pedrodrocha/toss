local herdr = require("toss.transports.herdr")

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
---@field resolve fun(name: string): TossTransport|nil, string|nil

---@type TossTransports
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
---@return TossTransport|nil, string|nil
function M.resolve(name)
  if name == "auto" then
    for _, transport_name in ipairs(M.priorities) do
      local transport = registered_transport(transport_name)
      if is_available(transport) then
        return transport
      end
    end

    return nil, "no transport is available"
  end

  local transport = registered_transport(name)
  if type(transport) ~= "table" then
    return nil, "unknown transport: " .. tostring(name)
  end

  return transport
end

return M
