---@alias TossErrorLevel "warn"|"error"

---@class TossError
---@field code string
---@field message string
---@field detail string|nil
---@field level TossErrorLevel

---@class TossErrors
---@field codes table<string, string>
---@field new fun(code: string, message: string, options: table|nil): TossError
---@field is fun(value: any): boolean
---@field message fun(value: any): string
---@field level fun(value: any): TossErrorLevel

local M = {}

M.codes = {
  setup_options = "invalid_setup_options",
  mapping_configuration = "invalid_mapping_configuration",
  mapping_setup = "mapping_setup_failed",
  mapping_teardown = "mapping_teardown_failed",
  which_key_registration = "which_key_registration_failed",
  transport_not_configured = "transport_not_configured",
  transport_configuration = "invalid_transport_configuration",
  unknown_transport = "unknown_transport",
  no_transport = "no_transport_available",
  invalid_transport = "invalid_transport",
  invalid_transport_result = "invalid_transport_result",
  invalid_transport_focus_result = "invalid_transport_focus_result",
  transport_focus = "transport_focus_failed",
  invalid_result = "invalid_result",
  context_capture = "context_capture_failed",
  context_origin = "invalid_context_origin",
  formatting = "context_formatting_failed",
  transport_failure = "transport_failed",
  buffer_not_file = "buffer_not_file",
  buffer_without_path = "buffer_without_path",
  invalid_context = "invalid_context",
  context_range = "invalid_context_range",
  context_kind = "invalid_context_kind",
  context_path = "invalid_context_path",
  context_text = "invalid_context_text",
  register_setup = "register_setup_failed",
  register_unavailable = "register_api_unavailable",
  register_read = "register_read_failed",
  telescope_unavailable = "telescope_unavailable",
  telescope_picker = "telescope_picker_unavailable",
  telescope_entry = "telescope_entry_unavailable",
  telescope_selection = "telescope_selection_unavailable",
  herdr_environment = "herdr_environment_unavailable",
  herdr_pane = "herdr_pane_unavailable",
  herdr_direction = "invalid_herdr_direction",
  herdr_command = "herdr_command_failed",
  herdr_spawn = "herdr_spawn_failed",
  herdr_process = "invalid_herdr_process",
  herdr_wait = "herdr_wait_failed",
  herdr_result = "invalid_herdr_result",
  herdr_response = "invalid_herdr_response",
  herdr_neighbor = "herdr_neighbor_unavailable",
  herdr_text = "invalid_herdr_text",
}

local valid_levels = {
  warn = true,
  error = true,
}

---@param code string
---@param message string
---@param options table|nil
---@return TossError
function M.new(code, message, options)
  options = type(options) == "table" and options or {}

  local level = options.level
  if not valid_levels[level] then
    level = "error"
  end

  return {
    code = type(code) == "string" and code or "unknown_error",
    message = type(message) == "string" and message or tostring(message),
    detail = options.detail ~= nil and tostring(options.detail) or nil,
    level = level,
  }
end

---@param value any
---@return boolean
function M.is(value)
  return type(value) == "table" and type(value.code) == "string" and type(value.message) == "string"
end

---@param value any
---@return string
function M.message(value)
  if not M.is(value) then
    return tostring(value)
  end

  if value.detail and value.detail ~= "" then
    return value.message .. ": " .. value.detail
  end

  return value.message
end

---@param value any
---@return TossErrorLevel
function M.level(value)
  if M.is(value) and valid_levels[value.level] then
    return value.level
  end

  return "error"
end

---@param code string
---@param message string
---@param level TossErrorLevel
---@param detail any
---@return TossError
local function defined(code, message, level, detail)
  return M.new(code, message, { level = level, detail = detail })
end

---@param code string
---@param message string
---@param level TossErrorLevel|nil
---@return fun(detail: any): TossError
local function constructor(code, message, level)
  return function(detail)
    return defined(code, message, level or "error", detail)
  end
end

M.setup_options = constructor(M.codes.setup_options, "setup options must be a table")
M.mapping_configuration = constructor(M.codes.mapping_configuration, "mappings must be true or a table")
M.mapping_key = function(direction)
  return defined(M.codes.mapping_configuration, "mapping for " .. direction .. " must be a string or false", "error")
end
M.mapping_setup = constructor(M.codes.mapping_setup, "mapping setup failed")
M.mapping_registration = function(direction, detail)
  return defined(M.codes.mapping_setup, "could not register " .. direction .. " mapping", "error", detail)
end
M.mapping_removal = function(direction, detail)
  return defined(M.codes.mapping_teardown, "could not remove " .. direction .. " mapping", "error", detail)
end
M.keymap_unavailable = constructor(M.codes.mapping_setup, "keymap API is unavailable")
M.keymap_delete_unavailable = constructor(M.codes.mapping_teardown, "keymap deletion API is unavailable")
M.which_key_registration = constructor(M.codes.which_key_registration, "which-key registration failed", "warn")
M.transport_not_configured = constructor(M.codes.transport_not_configured, "transport is not configured")
M.transport_configuration = constructor(
  M.codes.transport_configuration,
  "transport must be a name or a table with send(direction, text), focus(direction), and available()"
)
M.invalid_transport = constructor(
  M.codes.invalid_transport,
  "transport must provide send(direction, text), focus(direction), and available()"
)
M.invalid_transport_result = constructor(M.codes.invalid_transport_result, "transport must return a Result")
M.invalid_transport_focus_result =
  constructor(M.codes.invalid_transport_focus_result, "transport focus must return a Result")
M.invalid_result = function(operation)
  return defined(M.codes.invalid_result, operation .. " returned an invalid Result", "error")
end
M.context_capture = constructor(M.codes.context_capture, "context capture failed")
M.invalid_context_origin = function(origin)
  return defined(M.codes.context_origin, 'context origin must be "file_buffer" or "yank"', "error", origin)
end
M.could_not_capture = constructor(M.codes.context_capture, "could not capture context")
M.context_formatting = constructor(M.codes.formatting, "context formatting failed")
M.could_not_format = constructor(M.codes.formatting, "could not format context")
M.transport_resolution = constructor(M.codes.transport_failure, "transport resolution failed")
M.transport_failure = constructor(M.codes.transport_failure, "transport failed")
M.transport_focus = constructor(M.codes.transport_focus, "transport focus failed")
M.buffer_not_file = constructor(M.codes.buffer_not_file, "current buffer is not a file", "warn")
M.buffer_without_path = constructor(M.codes.buffer_without_path, "current buffer has no file path", "warn")
M.invalid_context = constructor(M.codes.invalid_context, "context must be a table")
M.invalid_context_kind = function(kind)
  return defined(M.codes.context_kind, 'context kind must be "file" or "text"', "error", kind)
end
M.invalid_context_path = constructor(M.codes.context_path, "context path must be a non-empty string")
M.invalid_context_text = constructor(M.codes.context_text, "context text must be a non-empty string")
M.register_setup = function(message, detail)
  return defined(M.codes.register_setup, message, "error", detail)
end
M.register_unavailable = constructor(M.codes.register_unavailable, "unnamed register API is unavailable")
M.register_read = function(message, detail)
  return defined(M.codes.register_read, message, "error", detail)
end
M.telescope_unavailable = constructor(M.codes.telescope_unavailable, "Telescope is not available")
M.telescope_picker = constructor(M.codes.telescope_picker, "no active Telescope picker found", "warn")
M.telescope_entry = constructor(M.codes.telescope_entry, "no Telescope cursor entry found", "warn")
M.telescope_selection = constructor(M.codes.telescope_selection, "could not read Telescope multi-selection")
M.context_range = function(message)
  return defined(M.codes.context_range, message, "error")
end
M.unknown_transport = function(name)
  return defined(M.codes.unknown_transport, "unknown transport: " .. tostring(name), "error")
end
M.no_transport = constructor(M.codes.no_transport, "no transport is available", "warn")

M.herdr_environment = constructor(M.codes.herdr_environment, "Herdr transport requires Neovim to run inside Herdr")
M.herdr_pane = constructor(M.codes.herdr_pane, "Herdr transport requires HERDR_PANE_ID")
M.herdr_direction = constructor(M.codes.herdr_direction, "invalid Herdr neighbor direction")
M.herdr_command = function(message, detail)
  return defined(M.codes.herdr_command, message, "error", detail)
end
M.herdr_spawn = function(message, detail)
  return defined(M.codes.herdr_spawn, message, "error", detail)
end
M.herdr_process = function(message)
  return defined(M.codes.herdr_process, message, "error")
end
M.herdr_wait = function(message, detail)
  return defined(M.codes.herdr_wait, message, "error", detail)
end
M.herdr_result = function(message)
  return defined(M.codes.herdr_result, message or "Herdr command returned no result", "error")
end
M.herdr_response = function(message, detail)
  return defined(M.codes.herdr_response, message, "error", detail)
end
M.herdr_neighbor = function(direction)
  return defined(M.codes.herdr_neighbor, "no adjacent Herdr pane found in direction " .. direction, "warn")
end
M.herdr_text = constructor(M.codes.herdr_text, "Herdr send-text requires text")

return M
