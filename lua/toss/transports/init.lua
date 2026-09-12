local herdr = require("toss.transports.herdr")

local M = {
  registry = {
    herdr = herdr,
  },
  priorities = {
    "herdr",
  },
}

local function is_available(transport)
  if type(transport) ~= "table" or type(transport.available) ~= "function" then
    return false
  end

  local ok, available = pcall(transport.available)
  return ok and available == true
end

local function registered_transport(name)
  for _, transport_name in ipairs(M.priorities) do
    if transport_name == name then
      return M.registry[name]
    end
  end

  return nil
end

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
