local context = require("toss.context")
local errors = require("toss.errors")
local formatter = require("toss.formatter")
local result = require("toss.result")
local transports = require("toss.transports")

---@class TossRunner
---@field run fun(direction: TossDirection, mode: TossContextMode|nil, config: TossConfig|nil): TossResult<nil>

local M = {}

---@param config TossConfig|nil
---@return TossResult<TossTransport>
local function resolve_transport(config)
  local configured = type(config) == "table" and config.transport

  if type(configured) == "string" then
    local resolved = transports.resolve(configured)
    if resolved.kind == "err" then
      return result.err(resolved.error)
    end

    configured = resolved.value
  end

  if configured == nil or configured == false then
    return result.err(errors.transport_not_configured())
  end

  if type(configured) ~= "table" then
    return result.err(errors.transport_configuration())
  end

  if type(configured.send) ~= "function" then
    return result.err(errors.invalid_transport())
  end

  return result.ok(configured)
end

---@param direction TossDirection
---@param mode TossContextMode|nil
---@param config TossConfig|nil
---@return TossResult<nil>
function M.run(direction, mode, config)
  local resolve_ok, transport_result = pcall(resolve_transport, config)
  if not resolve_ok then
    return result.err(errors.transport_resolution(transport_result))
  end

  if not result.is(transport_result) then
    return result.err(errors.invalid_result("transport resolution"))
  end

  if transport_result.kind == "err" then
    return result.err(transport_result.error)
  end

  local transport = transport_result.value
  local capture_ok, capture_result = pcall(context.capture, mode)
  if not capture_ok then
    return result.err(errors.context_capture(capture_result))
  end

  if not result.is(capture_result) then
    return result.err(errors.invalid_result("context capture"))
  end

  if capture_result.kind == "err" then
    return result.err(capture_result.error)
  end

  local captured = capture_result.value
  local format_ok, format_result = pcall(formatter.format, captured)
  if not format_ok then
    return result.err(errors.context_formatting(format_result))
  end

  if not result.is(format_result) then
    return result.err(errors.invalid_result("context formatting"))
  end

  if format_result.kind == "err" then
    return result.err(format_result.error)
  end

  local payload = format_result.value
  local send_ok, send_result = pcall(transport.send, direction, payload)
  if not send_ok then
    return result.err(errors.transport_failure(send_result))
  end

  if not result.is(send_result) then
    return result.err(errors.invalid_transport_result())
  end

  if send_result.kind == "err" then
    return result.err(send_result.error)
  end

  return result.ok()
end

return M
