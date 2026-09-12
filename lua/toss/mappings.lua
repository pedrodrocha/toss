---@class TossMappingModule
---@field setup fun(configured: boolean|TossMappings|nil, callbacks: table<TossDirection, fun(): boolean>, yank_callbacks: table<TossDirection, fun(): boolean>): TossResult<nil>

local errors = require("toss.errors")
local result = require("toss.result")
local M = {}

local mapping_order = {
  { direction = "left", key = "h" },
  { direction = "down", key = "j" },
  { direction = "up", key = "k" },
  { direction = "right", key = "l" },
}

---@param configured boolean|TossMappings|nil
---@param callbacks table<TossDirection, fun(): boolean>
---@param prefix string
---@param description_prefix string
---@return TossResult<nil>
local function register_mappings(configured, callbacks, prefix, description_prefix)
  if configured == nil or configured == false then
    return result.ok()
  end

  if configured == true then
    configured = {}
  elseif type(configured) ~= "table" then
    return result.err(errors.mapping_configuration())
  end

  if type(vim) ~= "table" or type(vim.keymap) ~= "table" or type(vim.keymap.set) ~= "function" then
    return result.err(errors.keymap_unavailable())
  end

  for _, mapping in ipairs(mapping_order) do
    local direction = mapping.direction
    local key = configured[direction]
    if key == nil then
      key = prefix .. mapping.key
    end

    if key ~= false and type(key) ~= "string" then
      return result.err(errors.mapping_key(direction))
    end

    if type(key) == "string" and key ~= "" then
      local registered, registration_error = pcall(vim.keymap.set, { "n", "x" }, key, callbacks[direction], {
        silent = true,
        desc = description_prefix .. direction,
      })
      if not registered then
        return result.err(errors.mapping_registration(direction, registration_error))
      end
    end
  end

  return result.ok()
end

---@param configured boolean|TossMappings|nil
---@param callbacks table<TossDirection, fun(): boolean>
---@param yank_callbacks table<TossDirection, fun(): boolean>|nil
---@return TossResult<nil>
function M.setup(configured, callbacks, yank_callbacks)
  local normal_result = register_mappings(configured, callbacks, "<leader>t", "Toss ")
  if normal_result.kind == "err" then
    return normal_result
  end

  if configured == nil or configured == false or yank_callbacks == nil then
    return result.ok()
  end

  local yank_configured = true
  if type(configured) == "table" and configured.yank ~= nil then
    yank_configured = configured.yank
  end

  return register_mappings(yank_configured, yank_callbacks, "<leader>ty", "Toss yank ")
end

return M
