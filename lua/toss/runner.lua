local context = require("toss.context")
local formatter = require("toss.formatter")
local transports = require("toss.transports")

---@class TossRunner
---@field resolve_transport fun(config: TossConfig|nil): TossTransport|nil, string|nil
---@field run fun(direction: TossDirection, config: TossConfig|nil): boolean, string|nil

---@type TossRunner
local M = {}

---@param config TossConfig|nil
---@return TossTransport|nil, string|nil
local function resolve_transport(config)
  local configured = type(config) == "table" and config.transport

  if type(configured) == "string" then
    local transport_name = configured
    local transport, transport_error = transports.resolve(transport_name)
    if not transport then
      return nil, transport_error
    end

    configured = transport
  end

  if type(configured) ~= "table" then
    return nil, "transport is not configured"
  end

  if type(configured.send) ~= "function" then
    return nil, "transport must provide send(direction, text)"
  end

  return configured
end

---@param config TossConfig|nil
---@return TossTransport|nil, string|nil
function M.resolve_transport(config)
  return resolve_transport(config)
end

---@param direction TossDirection
---@param config TossConfig|nil
---@return boolean, string|nil
function M.run(direction, config)
  local transport, transport_error = resolve_transport(config)
  if not transport then
    return false, transport_error
  end

  local capture_ok, captured, capture_error = pcall(context.capture)
  if not capture_ok then
    return false, "context capture failed: " .. tostring(captured)
  end

  if not captured then
    return false, capture_error or "could not capture context"
  end

  local format_ok, payload, format_error = pcall(formatter.format, captured)
  if not format_ok then
    return false, "context formatting failed: " .. tostring(payload)
  end

  if not payload then
    return false, format_error or "could not format context"
  end

  local send_ok, sent, send_error = pcall(transport.send, direction, payload)
  if not send_ok then
    return false, "transport failed: " .. tostring(sent)
  end

  if sent == false or (sent == nil and send_error ~= nil) then
    return false, send_error or "transport failed"
  end

  return true
end

return M
