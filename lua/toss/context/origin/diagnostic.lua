---@class TossDiagnosticOriginModule
---@field capture fun(): TossResult<TossDiagnosticContext|TossDiagnosticSetContext>

local errors = require("toss.errors")
local file_buffer = require("toss.context.origin.file_buffer")
local result = require("toss.result")
local M = {}

---@param line any
---@return boolean
local function is_zero_based_line(line)
  return type(line) == "number" and line >= 0 and line % 1 == 0
end

---@param severity any
---@return string|nil, string|nil
local function normalize_severity(severity)
  if severity == nil then
    return nil
  end

  if type(severity) == "string" then
    if severity == "" then
      return nil
    end
    return string.lower(severity)
  end

  if type(severity) ~= "number" then
    return nil, "severity must be a Neovim severity value"
  end

  local values = vim.diagnostic.severity
  local names = {
    [values.ERROR] = "error",
    [values.WARN] = "warning",
    [values.INFO] = "info",
    [values.HINT] = "hint",
  }
  local name = names[severity]
  if not name then
    return nil, "severity is not a recognized Neovim severity value"
  end

  return name
end

---@param diagnostic table
---@param path string
---@return TossDiagnosticContext|nil, string|nil
local function normalize_diagnostic(diagnostic, path)
  local lnum = diagnostic.lnum
  local end_lnum = diagnostic.end_lnum
  if end_lnum == nil then
    end_lnum = lnum
  end
  if not is_zero_based_line(end_lnum) then
    return nil, "end_lnum must be a non-negative integer"
  end

  local start_lnum = math.min(lnum, end_lnum)
  local finish_lnum = math.max(lnum, end_lnum)
  if type(diagnostic.message) ~= "string" or diagnostic.message:match("%S") == nil then
    return nil, "message must be a non-empty string"
  end

  local severity, severity_error = normalize_severity(diagnostic.severity)
  if severity_error then
    return nil, severity_error
  end

  local source
  if type(diagnostic.source) == "string" and diagnostic.source ~= "" then
    source = diagnostic.source
  end

  local code
  if type(diagnostic.code) == "string" and diagnostic.code ~= "" then
    code = diagnostic.code
  elseif type(diagnostic.code) == "number" and diagnostic.code % 1 == 0 then
    code = diagnostic.code
  end

  return {
    kind = "diagnostic",
    path = path,
    start_line = start_lnum + 1,
    end_line = finish_lnum + 1,
    message = diagnostic.message,
    severity = severity,
    source = source,
    code = code,
  }
end

---@return TossResult<string>
local function capture_path()
  local file_result = file_buffer.capture()
  if file_result:is_err() then
    return result.err(file_result.error)
  end

  return result.ok(file_result.value.path)
end

---@return TossResult<any[]>
local function get_current_buffer_diagnostics()
  local bufnr = vim.api.nvim_get_current_buf()
  local ok, diagnostics = pcall(vim.diagnostic.get, bufnr)
  if not ok then
    return result.err(errors.could_not_capture("could not read Neovim diagnostics: " .. tostring(diagnostics)))
  end
  if type(diagnostics) ~= "table" then
    return result.err(errors.could_not_capture("Neovim returned an invalid diagnostic list"))
  end

  return result.ok(diagnostics)
end

---@param diagnostics any[]
---@param cursor_lnum integer
---@return TossResult<any[]>
local function select_diagnostics(diagnostics, cursor_lnum)
  local line_diagnostics = {}
  for _, diagnostic in ipairs(diagnostics) do
    if type(diagnostic) ~= "table" or not is_zero_based_line(diagnostic.lnum) then
      return result.err(errors.could_not_capture("a diagnostic has no valid start line"))
    end
    if diagnostic.lnum == cursor_lnum then
      line_diagnostics[#line_diagnostics + 1] = diagnostic
    end
  end

  local selected = #line_diagnostics > 0 and line_diagnostics or diagnostics
  if #selected == 0 then
    return result.err(errors.no_diagnostics())
  end

  return result.ok(selected)
end

---@param diagnostics any[]
---@param path string
---@return TossResult<TossDiagnosticContext[]>
local function normalize_diagnostics(diagnostics, path)
  local items = {}
  for index, diagnostic in ipairs(diagnostics) do
    local normalized, normalization_error = normalize_diagnostic(diagnostic, path)
    if not normalized then
      return result.err(errors.could_not_capture("invalid selected diagnostic: " .. normalization_error))
    end
    items[index] = normalized
  end

  return result.ok(items)
end

---@param items TossDiagnosticContext[]
---@return TossDiagnosticContext|TossDiagnosticSetContext
local function make_context(items)
  if #items == 1 then
    return items[1]
  end

  return {
    kind = "diagnostic_set",
    items = items,
  }
end

---@return TossResult<TossDiagnosticContext|TossDiagnosticSetContext>
function M.capture()
  local path_result = capture_path()
  if path_result:is_err() then
    return result.err(path_result.error)
  end

  local diagnostics_result = get_current_buffer_diagnostics()
  if diagnostics_result:is_err() then
    return result.err(diagnostics_result.error)
  end

  local cursor_lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
  local selection_result = select_diagnostics(diagnostics_result.value, cursor_lnum)
  if selection_result:is_err() then
    return result.err(selection_result.error)
  end

  local items_result = normalize_diagnostics(selection_result.value, path_result.value)
  if items_result:is_err() then
    return result.err(items_result.error)
  end

  return result.ok(make_context(items_result.value))
end

return M
