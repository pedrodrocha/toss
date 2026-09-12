local M = {}

local function invalid(message)
  return nil, message
end

local function assert_buffer_is_file()
  if vim.bo.buftype ~= "" then
    return invalid("current buffer is not a file")
  end
end

local function assert_is_file_path(absolute_path)
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

  _, err = assert_is_file_path(absolute_path)
  if err then
    return nil, err
  end

  local root = vim.fs.root(0, ".git") or vim.fn.getcwd()
  local relative_path = vim.fs.relpath(root, absolute_path)
  if not relative_path or relative_path == "" then
    return invalid("current file is outside the project root")
  end

  return {
    path = relative_path,
    start_line = nil,
    end_line = nil,
  }
end

return M
