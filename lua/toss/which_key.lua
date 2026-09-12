---@class TossWhichKeyModule
---@field setup fun(configured: boolean|nil): TossResult<nil>

local errors = require("toss.errors")
local result = require("toss.result")
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
---@return TossResult<nil>
function M.setup(configured)
  if configured ~= true then
    return result.ok()
  end

  local ok, which_key = pcall(require, "which-key")
  if not ok then
    return result.ok()
  end

  if type(which_key) ~= "table" then
    return result.ok()
  end

  if type(which_key.add) == "function" then
    local register_ok, register_error = pcall(which_key.add, registration())
    if not register_ok then
      return result.err(errors.which_key_registration(register_error))
    end
  end

  return result.ok()
end

return M
