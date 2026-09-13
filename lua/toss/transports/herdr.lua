---@alias TossCommandResult { code: integer|nil, stdout: string|nil, stderr: string|nil }

---@class TossHerdrTransport : TossTransport
---@field neighbor fun(direction: TossDirection): TossResult<string>

local errors = require("toss.errors")
local result = require("toss.result")
local M = {}

---@type table<TossDirection, boolean>
local valid_directions = {
  left = true,
  down = true,
  up = true,
  right = true,
}

---@param value string
---@return string
local function trim(value)
  local trimmed = value:gsub("^%s+", ""):gsub("%s+$", "")
  return trimmed
end

---@param command_result TossCommandResult
---@return string
local function command_detail(command_result)
  local details = {}

  for _, output in ipairs({ command_result.stderr, command_result.stdout }) do
    if type(output) == "string" then
      output = trim(output)
      if output ~= "" then
        details[#details + 1] = output
      end
    end
  end

  return table.concat(details, " | ")
end

---@param command_result TossCommandResult
---@param operation string
---@return TossError
local function command_failure(command_result, operation)
  local message = operation .. " failed"
  if command_result.code ~= nil then
    message = message .. " (exit code " .. tostring(command_result.code) .. ")"
  end

  return errors.herdr_command(message, command_detail(command_result))
end

---@param direction TossDirection
---@return TossResult<TossDirection>
local function validate_direction(direction)
  if not valid_directions[direction] then
    return result.err(errors.herdr_direction())
  end

  return result.ok(direction)
end

---@return TossResult<string>
local function validate_environment()
  if type(vim) ~= "table" or type(vim.env) ~= "table" or vim.env.HERDR_ENV ~= "1" then
    return result.err(errors.herdr_environment())
  end

  local source_pane_id = vim.env.HERDR_PANE_ID
  if type(source_pane_id) ~= "string" or source_pane_id == "" then
    return result.err(errors.herdr_pane())
  end

  return result.ok(source_pane_id)
end

---@param argv string[]
---@param operation string
---@return TossResult<TossCommandResult>
local function run_command(argv, operation)
  if type(vim) ~= "table" or type(vim.system) ~= "function" then
    return result.err(errors.herdr_spawn(operation .. " requires Neovim's vim.system API"))
  end

  local started, process = pcall(vim.system, argv)
  if not started then
    return result.err(errors.herdr_spawn("could not start " .. operation, process))
  end

  if type(process) ~= "table" or type(process.wait) ~= "function" then
    return result.err(errors.herdr_process(operation .. " did not return a process"))
  end

  local waited, command_result = pcall(process.wait, process)
  if not waited then
    return result.err(errors.herdr_wait(operation .. " failed", command_result))
  end

  if type(command_result) ~= "table" then
    return result.err(errors.herdr_result(operation .. " returned no result"))
  end

  if command_result.code ~= 0 then
    return result.err(command_failure(command_result, operation))
  end

  return result.ok(command_result)
end

---@param source_pane_id string
---@param direction TossDirection
---@return TossResult<TossCommandResult>
local function run_neighbor(source_pane_id, direction)
  return run_command({
    "herdr",
    "pane",
    "neighbor",
    "--pane",
    source_pane_id,
    "--direction",
    direction,
  }, "Herdr neighbor lookup")
end

---@param source_pane_id string
---@param direction TossDirection
---@return TossResult<nil>
local function focus_pane(source_pane_id, direction)
  local focus_result = run_command({
    "herdr",
    "pane",
    "focus",
    "--pane",
    source_pane_id,
    "--direction",
    direction,
  }, "Herdr focus")
  if focus_result.kind == "err" then
    return result.err(focus_result.error)
  end

  return result.ok()
end

---@param stdout string|nil
---@param direction TossDirection
---@return TossResult<string>
local function decode_neighbor(stdout, direction)
  if type(vim) ~= "table" or type(vim.json) ~= "table" or type(vim.json.decode) ~= "function" then
    return result.err(errors.herdr_response("Herdr neighbor lookup requires vim.json.decode"))
  end

  local decoded, response = pcall(vim.json.decode, stdout or "")
  if not decoded then
    return result.err(errors.herdr_response("could not decode Herdr neighbor response", response))
  end

  local result_data = type(response) == "table" and response.result
  local neighbor = type(result_data) == "table" and result_data.neighbor
  local destination_pane_id = type(neighbor) == "table" and neighbor.neighbor_pane_id

  if type(destination_pane_id) ~= "string" or destination_pane_id == "" then
    return result.err(errors.herdr_neighbor(direction))
  end

  return result.ok(destination_pane_id)
end

---@param direction TossDirection
---@return TossResult<string>
function M.neighbor(direction)
  local direction_result = validate_direction(direction)
  if direction_result.kind == "err" then
    return direction_result
  end

  local source_result = validate_environment()
  if source_result.kind == "err" then
    return source_result
  end

  local source_pane_id = source_result.value
  local direction_value = direction_result.value
  local command_result = run_neighbor(source_pane_id, direction_value)
  if command_result.kind == "err" then
    return command_result
  end

  local command_output = command_result.value
  return decode_neighbor(command_output.stdout, direction_value)
end

---@param direction TossDirection
---@param text string
---@return TossResult<nil>
function M.send(direction, text)
  if type(text) ~= "string" then
    return result.err(errors.herdr_text())
  end

  local neighbor_result = M.neighbor(direction)
  if neighbor_result.kind == "err" then
    return result.err(neighbor_result.error)
  end

  local destination_pane_id = neighbor_result.value
  local send_result = run_command({
    "herdr",
    "pane",
    "send-text",
    destination_pane_id,
    text,
  }, "Herdr send-text")
  if send_result.kind == "err" then
    return result.err(send_result.error)
  end

  return result.ok()
end

---@param direction TossDirection
---@return TossResult<nil>
function M.focus(direction)
  local direction_result = validate_direction(direction)
  if direction_result.kind == "err" then
    return result.err(direction_result.error)
  end

  local source_result = validate_environment()
  if source_result.kind == "err" then
    return result.err(source_result.error)
  end

  return focus_pane(source_result.value, direction_result.value)
end

---@return boolean
function M.available()
  return validate_environment().kind == "ok"
end

return M
