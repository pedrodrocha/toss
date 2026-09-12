local M = {}

local valid_directions = {
  left = true,
  down = true,
  up = true,
  right = true,
}

local function trim(value)
  return value:gsub("^%s+", ""):gsub("%s+$", "")
end

local function command_detail(result)
  local details = {}

  for _, output in ipairs({ result.stderr, result.stdout }) do
    if type(output) == "string" then
      output = trim(output)
      if output ~= "" then
        details[#details + 1] = output
      end
    end
  end

  return table.concat(details, " | ")
end

local function command_failure(result)
  local message = "Herdr neighbor lookup failed"
  if result.code ~= nil then
    message = message .. " (exit code " .. tostring(result.code) .. ")"
  end

  local detail = command_detail(result)
  if detail ~= "" then
    message = message .. ": " .. detail
  end

  return message
end

local function validate_direction(direction)
  if not valid_directions[direction] then
    return nil, "invalid Herdr neighbor direction"
  end

  return direction
end

local function validate_environment()
  if type(vim) ~= "table" or type(vim.env) ~= "table" or vim.env.HERDR_ENV ~= "1" then
    return nil, "Herdr transport requires Neovim to run inside Herdr"
  end

  local source_pane_id = vim.env.HERDR_PANE_ID
  if type(source_pane_id) ~= "string" or source_pane_id == "" then
    return nil, "Herdr transport requires HERDR_PANE_ID"
  end

  return source_pane_id
end

local function run_neighbor(source_pane_id, direction)
  if type(vim.system) ~= "function" then
    return nil, "Herdr transport requires Neovim's vim.system API"
  end

  local started, process = pcall(vim.system, {
    "herdr",
    "pane",
    "neighbor",
    "--pane",
    source_pane_id,
    "--direction",
    direction,
  })
  if not started then
    return nil, "could not start Herdr neighbor lookup: " .. tostring(process)
  end

  if type(process) ~= "table" or type(process.wait) ~= "function" then
    return nil, "Herdr neighbor lookup did not return a process"
  end

  local waited, result = pcall(process.wait, process)
  if not waited then
    return nil, "Herdr neighbor lookup failed: " .. tostring(result)
  end

  if type(result) ~= "table" then
    return nil, "Herdr neighbor lookup returned no result"
  end

  if result.code ~= 0 then
    return nil, command_failure(result)
  end

  return result
end

local function decode_neighbor(stdout, direction)
  if type(vim.json) ~= "table" or type(vim.json.decode) ~= "function" then
    return nil, "Herdr neighbor lookup requires vim.json.decode"
  end

  local decoded, response = pcall(vim.json.decode, stdout or "")
  if not decoded then
    return nil, "could not decode Herdr neighbor response: " .. tostring(response)
  end

  local result_data = type(response) == "table" and response.result
  local neighbor = type(result_data) == "table" and result_data.neighbor
  local destination_pane_id = type(neighbor) == "table" and neighbor.neighbor_pane_id

  if type(destination_pane_id) ~= "string" or destination_pane_id == "" then
    return nil, "no adjacent Herdr pane found in direction " .. direction
  end

  return destination_pane_id
end

function M.neighbor(direction)
  local direction_error
  direction, direction_error = validate_direction(direction)
  if not direction then
    return nil, direction_error
  end

  local source_pane_id, environment_error = validate_environment()
  if not source_pane_id then
    return nil, environment_error
  end

  local result, command_error = run_neighbor(source_pane_id, direction)
  if not result then
    return nil, command_error
  end

  return decode_neighbor(result.stdout, direction)
end

return M
