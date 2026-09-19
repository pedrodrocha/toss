---@class TossContextPathModule
---@field relative_or_absolute fun(absolute_path: string, bufnr: integer|nil): string
---@field is_directory fun(absolute_path: string): boolean

local project_root = require("toss.context.root")
local M = {}

---@param root string|nil
---@param absolute_path string
---@return string|nil
local function relative_path(root, absolute_path)
  if not root then
    return nil
  end

  local ok, path = pcall(vim.fs.relpath, root, absolute_path)
  if ok and path ~= "" then
    return path
  end

  return nil
end

---@param absolute_path string
---@param bufnr integer|nil
---@return string
function M.relative_or_absolute(absolute_path, bufnr)
  local root = project_root.resolve(bufnr or 0)
  return relative_path(root, absolute_path) or absolute_path
end

---@param absolute_path string
---@return boolean
function M.is_directory(absolute_path)
  local uv = vim.uv or vim.loop
  local ok, stat = pcall(uv.fs_stat, absolute_path)
  return ok and stat ~= nil and stat.type == "directory"
end

return M
