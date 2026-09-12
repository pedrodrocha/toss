local M = {}
local project_root = require("toss.context.project_root")

local function invalid(message)
  return nil, message
end

local function assert_buffer_is_file()
  if vim.bo.buftype ~= "" then
    return invalid("current buffer is not a file")
  end
end

local function validate_file_path(absolute_path)
  if absolute_path == "" then
    return invalid("current buffer has no file path")
  end
end

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
  if not root then
    return invalid("could not determine project root")
  end

  local relative_path = vim.fs.relpath(root, absolute_path)
  local path = relative_path
  if not path or path == "" then
    path = absolute_path
  end

  return {
    path = path,
    start_line = nil,
    end_line = nil,
  }
end

return M
