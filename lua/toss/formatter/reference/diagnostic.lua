---@type TossContextFormatter<TossDiagnosticContext|TossDiagnosticSetContext>
local M = {}

local errors = require("toss.errors")
local result = require("toss.result")

---@param value any
---@return boolean
local function is_positive_integer(value)
  return type(value) == "number" and value >= 1 and value % 1 == 0
end

---@param message string
---@return string
local function normalize_message(message)
  return (message:gsub("%s+", " "):match("^%s*(.-)%s*$"))
end

---@param value any
---@return boolean
local function is_optional_label(value)
  if value == nil then
    return true
  end

  if type(value) ~= "string" or value == "" then
    return false
  end

  return true
end

---@param ctx any
---@return TossDiagnosticContext|nil, string|nil
local function normalize_diagnostic(ctx)
  if type(ctx) ~= "table" then
    return nil, "must be a table"
  end
  if ctx.kind ~= "diagnostic" then
    return nil, 'kind must be "diagnostic"'
  end
  if type(ctx.path) ~= "string" or ctx.path == "" then
    return nil, "path must be a non-empty string"
  end
  if not is_positive_integer(ctx.start_line) then
    return nil, "start_line must be a positive integer"
  end
  if not is_positive_integer(ctx.end_line) or ctx.end_line < ctx.start_line then
    return nil, "end_line must be an integer greater than or equal to start_line"
  end
  if type(ctx.message) ~= "string" then
    return nil, "message must be a string"
  end

  local message = normalize_message(ctx.message)
  if message == "" then
    return nil, "message must not be empty"
  end
  if not is_optional_label(ctx.severity) then
    return nil, "severity must be a non-empty string when provided"
  end
  if not is_optional_label(ctx.source) then
    return nil, "source must be a non-empty string when provided"
  end
  if
    ctx.code ~= nil
    and not (type(ctx.code) == "string" and ctx.code ~= "")
    and not (type(ctx.code) == "number" and ctx.code % 1 == 0)
  then
    return nil, "code must be a non-empty string or integer when provided"
  end

  return {
    kind = "diagnostic",
    path = ctx.path,
    start_line = ctx.start_line,
    end_line = ctx.end_line,
    message = message,
    severity = ctx.severity,
    source = ctx.source,
    code = ctx.code,
  }
end

---@param diagnostic TossDiagnosticContext
---@return string
local function format_diagnostic_details(diagnostic)
  local metadata = {}
  if diagnostic.severity ~= nil then
    metadata[#metadata + 1] = diagnostic.severity
  end
  if diagnostic.source ~= nil then
    metadata[#metadata + 1] = diagnostic.source
  end
  if diagnostic.code ~= nil then
    metadata[#metadata + 1] = tostring(diagnostic.code)
  end

  if #metadata == 0 then
    return diagnostic.message
  end

  return "[" .. table.concat(metadata, " ") .. "] " .. diagnostic.message
end

---@param diagnostic TossDiagnosticContext
---@return string
local function format_single_diagnostic(diagnostic)
  return string.format(
    "@%s#L%d-L%d — %s",
    diagnostic.path,
    diagnostic.start_line,
    diagnostic.end_line,
    format_diagnostic_details(diagnostic)
  )
end

---@param ctx TossDiagnosticContext
---@return TossResult<string>
local function format_diagnostic(ctx)
  local diagnostic, validation_error = normalize_diagnostic(ctx)
  if not diagnostic then
    return result.err(errors.context_formatting("invalid diagnostic context: " .. validation_error))
  end

  return result.ok(format_single_diagnostic(diagnostic))
end

---@param items any
---@return TossDiagnosticContext[]|nil, string|nil
local function normalize_diagnostic_items(items)
  if type(items) ~= "table" then
    return nil, "items must be an array"
  end

  local count, maximum = 0, 0
  for key in pairs(items) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      return nil, "items must be an array"
    end
    count = count + 1
    maximum = math.max(maximum, key)
  end
  if count == 0 or count ~= maximum then
    return nil, "items must be a non-empty array"
  end

  local normalized = {}
  for index = 1, maximum do
    local diagnostic, validation_error = normalize_diagnostic(items[index])
    if not diagnostic then
      return nil, string.format("item %d is invalid: %s", index, validation_error)
    end
    normalized[index] = diagnostic
  end

  return normalized
end

---@param ctx TossDiagnosticSetContext
---@return TossResult<string>
local function format_diagnostic_set(ctx)
  local items, validation_error = normalize_diagnostic_items(ctx.items)
  if not items then
    return result.err(errors.context_formatting("invalid diagnostic set context: " .. validation_error))
  end

  local first = items[1]
  local same_path = true
  local same_range = true
  for index = 2, #items do
    local item = items[index]
    if item.path ~= first.path then
      same_path = false
      same_range = false
      break
    end
    if item.start_line ~= first.start_line or item.end_line ~= first.end_line then
      same_range = false
    end
  end

  if not same_path then
    local lines = {}
    for index, item in ipairs(items) do
      lines[index] = format_single_diagnostic(item)
    end
    return result.ok(table.concat(lines, "\n"))
  end

  local lines = {}
  if same_range then
    lines[1] = string.format("@%s#L%d-L%d", first.path, first.start_line, first.end_line)
    for index, item in ipairs(items) do
      lines[index + 1] = format_diagnostic_details(item)
    end
  else
    lines[1] = "@" .. first.path
    for index, item in ipairs(items) do
      lines[index + 1] = string.format("L%d-L%d %s", item.start_line, item.end_line, format_diagnostic_details(item))
    end
  end

  return result.ok(table.concat(lines, "\n"))
end

---@param ctx TossDiagnosticContext|TossDiagnosticSetContext
---@return TossResult<string>
function M.format(ctx)
  if ctx.kind == "diagnostic" then
    return format_diagnostic(ctx)
  end

  if ctx.kind == "diagnostic_set" then
    return format_diagnostic_set(ctx)
  end

  return result.err(errors.context_formatting("unsupported diagnostic context kind: " .. tostring(ctx.kind)))
end

return M
