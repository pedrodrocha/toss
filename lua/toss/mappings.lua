---@class TossMappingModule
---@field resolve fun(configured: boolean|TossMappings|nil): TossMappings|nil, string|nil
---@field setup fun(configured: boolean|TossMappings|nil, callbacks: table<TossDirection, fun(): boolean>): boolean, string|nil

---@type TossMappingModule
local M = {}

local mapping_order = { "left", "down", "up", "right" }
local default_mappings = {
  left = "<leader>th",
  down = "<leader>tj",
  up = "<leader>tk",
  right = "<leader>tl",
}

---@param configured boolean|TossMappings|nil
---@return TossMappings|nil, string|nil
function M.resolve(configured)
  if configured == nil or configured == false then
    return nil
  end

  if configured == true then
    return default_mappings
  end

  if type(configured) ~= "table" then
    return nil, "mappings must be true or a table"
  end

  local mappings = {}
  for _, direction in ipairs(mapping_order) do
    if configured[direction] == nil then
      mappings[direction] = default_mappings[direction]
    else
      mappings[direction] = configured[direction]
    end
  end

  return mappings
end

---@param configured boolean|TossMappings|nil
---@param callbacks table<TossDirection, fun()>
---@return boolean, string|nil
function M.setup(configured, callbacks)
  local mappings, resolve_error = M.resolve(configured)
  if not mappings then
    if resolve_error then
      return false, resolve_error
    end

    return true
  end

  if type(vim) ~= "table" or type(vim.keymap) ~= "table" or type(vim.keymap.set) ~= "function" then
    return false, "keymap API is unavailable"
  end

  for _, direction in ipairs(mapping_order) do
    local key = mappings[direction]
    if key ~= false and type(key) == "string" and key ~= "" then
      vim.keymap.set({ "n", "x" }, key, callbacks[direction], {
        silent = true,
        desc = "Toss " .. direction,
      })
    end
  end

  return true
end

return M
