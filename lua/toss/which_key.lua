---@class TossWhichKeyModule
---@field setup fun(configured: boolean|nil): boolean, string|nil

local M = {}

local group = "toss"
local icon = "󰧑"

local function registration()
  return {
    {
      "<leader>t",
      group = group,
      icon = icon,
      mode = { "n", "x" },
    },
  }
end

---@param configured boolean|nil
---@return boolean, string|nil
function M.setup(configured)
  if configured ~= true then
    return true
  end

  local ok, which_key = pcall(require, "which-key")
  if not ok then
    return true
  end

  if type(which_key) ~= "table" then
    return true
  end

  if type(which_key.add) == "function" then
    local register_ok, register_error = pcall(which_key.add, registration())
    if not register_ok then
      return false, "which-key registration failed: " .. tostring(register_error)
    end

    return true
  end

  return true
end

return M
