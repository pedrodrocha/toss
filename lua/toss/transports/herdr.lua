---@alias TossCommandResult { code: integer|nil, stdout: string|nil, stderr: string|nil }

---@class TossHerdrTransport : TossTransport
---@field neighbor fun(direction: TossDirection): string|nil, string|nil

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

---@param result TossCommandResult
---@return string
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

---@param result TossCommandResult
---@param operation string
---@return string
local function command_failure(result, operation)
	local message = operation .. " failed"
	if result.code ~= nil then
		message = message .. " (exit code " .. tostring(result.code) .. ")"
	end

	local detail = command_detail(result)
	if detail ~= "" then
		message = message .. ": " .. detail
	end

	return message
end

---@param direction TossDirection
---@return TossDirection|nil, string|nil
local function validate_direction(direction)
	if not valid_directions[direction] then
		return nil, "invalid Herdr neighbor direction"
	end

	return direction
end

---@return string|nil, string|nil
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

---@param argv string[]
---@param operation string
---@return TossCommandResult|nil, string|nil
local function run_command(argv, operation)
	if type(vim.system) ~= "function" then
		return nil, operation .. " requires Neovim's vim.system API"
	end

	local started, process = pcall(vim.system, argv)
	if not started then
		return nil, "could not start " .. operation .. ": " .. tostring(process)
	end

	if type(process) ~= "table" or type(process.wait) ~= "function" then
		return nil, operation .. " did not return a process"
	end

	local waited, result = pcall(process.wait, process)
	if not waited then
		return nil, operation .. " failed: " .. tostring(result)
	end

	if type(result) ~= "table" then
		return nil, operation .. " returned no result"
	end

	if result.code ~= 0 then
		return nil, command_failure(result, operation)
	end

	return result
end

---@param source_pane_id string
---@param direction TossDirection
---@return TossCommandResult|nil, string|nil
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

---@param stdout string|nil
---@param direction TossDirection
---@return string|nil, string|nil
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

---@param direction TossDirection
---@return string|nil, string|nil
function M.neighbor(direction)
	local validated_direction, direction_error = validate_direction(direction)
	if not validated_direction then
		return nil, direction_error
	end

	local source_pane_id, environment_error = validate_environment()
	if not source_pane_id then
		return nil, environment_error
	end

	local result, command_error = run_neighbor(source_pane_id, validated_direction)
	if not result then
		return nil, command_error
	end

	return decode_neighbor(result.stdout, validated_direction)
end

---@param direction TossDirection
---@param text string
---@return boolean, string|nil
function M.send(direction, text)
	if type(text) ~= "string" then
		return false, "Herdr send-text requires text"
	end

	local destination_pane_id, neighbor_error = M.neighbor(direction)
	if not destination_pane_id then
		return false, neighbor_error
	end

	local _, send_error = run_command({
		"herdr",
		"pane",
		"send-text",
		destination_pane_id,
		text,
	}, "Herdr send-text")
	if send_error then
		return false, send_error
	end

	return true
end

---@return boolean
function M.available()
	local source_pane_id = validate_environment()
	return source_pane_id ~= nil
end

return M
