---@class TossContext
---@field path string
---@field start_line integer|nil
---@field end_line integer|nil

---@class TossContextModule
---@field capture fun(): TossContext|nil, string|nil

local M = {}
local project_root = require("toss.context.root")

---@param message string
---@return nil, string
local function invalid(message)
	return nil, message
end

---@return nil, string|nil
local function assert_buffer_is_file()
	if vim.bo.buftype ~= "" then
		return invalid("current buffer is not a file")
	end
end

---@param absolute_path string
---@return nil, string|nil
local function validate_file_path(absolute_path)
	if absolute_path == "" then
		return invalid("current buffer has no file path")
	end
end

---@param root string|nil
---@param absolute_path string
---@return string
local function resolve_path(root, absolute_path)
	local relative_path = root and vim.fs.relpath(root, absolute_path)
	if relative_path and relative_path ~= "" then
		return relative_path
	end

	return absolute_path
end

---@return boolean
local function is_visual_mode()
	local mode = vim.api.nvim_get_mode().mode
	return mode == "v" or mode == "V" or mode == "\022"
end

---@return integer, integer
local function visual_range()
	local visual_start = vim.fn.getpos("v")
	local visual_end = vim.fn.getpos(".")

	return math.min(visual_start[2], visual_end[2]), math.max(visual_start[2], visual_end[2])
end

---@return TossContext|nil, string|nil
function M.capture()
	local _, err = assert_buffer_is_file()
	if err then
		return nil, err
	end

	local absolute_path = vim.api.nvim_buf_get_name(0)

	_, err = validate_file_path(absolute_path)
	if err then
		return nil, err
	end

	local root = project_root.resolve(0)
	local path = resolve_path(root, absolute_path)
	local start_line, end_line

	if is_visual_mode() then
		start_line, end_line = visual_range()
	end

	return {
		path = path,
		start_line = start_line,
		end_line = end_line,
	}
end

return M
