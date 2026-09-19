local M = {}

local origin = "telescope_file_browser"

---@param direction TossDirection
---@return fun(): boolean
local function callback(direction)
  return function()
    return require("toss")[direction](origin)
  end
end

---@param direction TossDirection
---@param description string
---@return table
local function action(direction, description)
  local action_callback = callback(direction)
  return setmetatable({ description }, {
    __call = function()
      return action_callback()
    end,
  })
end

---@return table
function M.mappings()
  return {
    n = {
      ["<leader>th"] = action("left", "Toss left"),
      ["<leader>tj"] = action("down", "Toss down"),
      ["<leader>tk"] = action("up", "Toss up"),
      ["<leader>tl"] = action("right", "Toss right"),
    },
    i = {},
  }
end

return M
