local context = require("toss.context")
local errors = require("toss.errors")
local formatter = require("toss.formatter")
local result = require("toss.result")
local transports = require("toss.transports")

---@class TossRunner
---@field setup fun(config: TossConfig|nil)
---@field run fun(direction: TossDirection, origin: TossOrigin|nil): TossResult<nil>

local M = {}
local configured_options

---@return TossResult<TossTransport>
local function resolve_transport()
  local configured = type(configured_options) == "table" and configured_options.transport or nil

  if type(configured) == "string" then
    local resolved = transports.resolve(configured)
    if resolved:is_err() then
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

  if
    type(configured.send) ~= "function"
    or type(configured.focus) ~= "function"
    or type(configured.available) ~= "function"
  then
    return result.err(errors.invalid_transport())
  end

  return result.ok(configured)
end

---@param origin TossOrigin
---@return TossResult<TossContext>
local function capture_context(origin)
  local capture_ok, capture_result = pcall(context.capture, origin)
  if not capture_ok then
    return result.err(errors.context_capture(capture_result))
  end

  if not result.is(capture_result) then
    return result.err(errors.invalid_result("context capture"))
  end

  return capture_result
end

---@param captured TossContext
---@return TossResult<string>
local function format_context(captured)
  local format_ok, format_result = pcall(formatter.format, captured)
  if not format_ok then
    return result.err(errors.context_formatting(format_result))
  end

  if not result.is(format_result) then
    return result.err(errors.invalid_result("context formatting"))
  end

  return format_result
end

---@param transport TossTransport
---@param direction TossDirection
---@param payload string
---@return TossResult<nil>
local function send_payload(transport, direction, payload)
  local send_ok, send_result = pcall(transport.send, direction, payload)
  if not send_ok then
    return result.err(errors.transport_failure(send_result))
  end

  if not result.is(send_result) then
    return result.err(errors.invalid_transport_result())
  end

  return send_result
end

---@param transport TossTransport
---@param direction TossDirection
---@return TossResult<nil>
local function focus_destination(transport, direction)
  local focus_ok, focus_result = pcall(transport.focus, direction)
  if not focus_ok then
    return result.err(errors.transport_focus(focus_result))
  end

  if not result.is(focus_result) then
    return result.err(errors.invalid_transport_focus_result())
  end

  return focus_result
end

---@param direction TossDirection
---@param origin TossOrigin|nil
---@return TossResult<nil>
function M.run(direction, origin)
  if origin == nil then
    origin = "file_buffer"
  end

  local resolve_ok, transport_result = pcall(resolve_transport)
  if not resolve_ok then
    return result.err(errors.transport_resolution(transport_result))
  end

  if not result.is(transport_result) then
    return result.err(errors.invalid_result("transport resolution"))
  end

  if transport_result:is_err() then
    return result.err(transport_result.error)
  end

  local transport = transport_result.value

  local capture_result = capture_context(origin)
  if capture_result:is_err() then
    return result.err(capture_result.error)
  end

  local format_result = format_context(capture_result.value)
  if format_result:is_err() then
    return result.err(format_result.error)
  end

  local send_result = send_payload(transport, direction, format_result.value)
  if send_result:is_err() then
    return result.err(send_result.error)
  end

  local focus_result = focus_destination(transport, direction)
  if focus_result:is_err() then
    return result.err(focus_result.error)
  end

  return result.ok()
end

---@param config TossConfig|nil
function M.setup(config)
  configured_options = config
end

return M
