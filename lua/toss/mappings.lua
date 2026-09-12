---@class TossMappingModule
---@field resolve fun(configured: boolean|TossMappings|nil): TossResult<TossMappings|nil>
---@field setup fun(configured: boolean|TossMappings|nil, callbacks: table<TossDirection, fun(): boolean>): TossResult<nil>

local errors = require("toss.errors")
local result = require("toss.result")
local M = {}

local mapping_order = { "left", "down", "up", "right" }
local default_mappings = {
  left = "<leader>th",
  down = "<leader>tj",
  up = "<leader>tk",
  right = "<leader>tl",
}

---@param configured boolean|TossMappings|nil
---@return TossResult<TossMappings|nil>
function M.resolve(configured)
  if configured == nil or configured == false then
    return result.ok()
  end

  if configured == true then
    return result.ok(default_mappings)
  end

  if type(configured) ~= "table" then
    return result.err(errors.mapping_configuration())
  end

  local mappings = {}
  for _, direction in ipairs(mapping_order) do
    if configured[direction] == nil then
      mappings[direction] = default_mappings[direction]
    else
      mappings[direction] = configured[direction]
    end
  end

  return result.ok(mappings)
end

---@param configured boolean|TossMappings|nil
---@param callbacks table<TossDirection, fun(): boolean>
---@return TossResult<nil>
function M.setup(configured, callbacks)
  local resolved = M.resolve(configured)
  if resolved.kind == "err" then
    return resolved
  end

  local mappings = resolved.value
  if mappings == nil then
    return result.ok()
  end

  if type(vim) ~= "table" or type(vim.keymap) ~= "table" or type(vim.keymap.set) ~= "function" then
    return result.err(errors.keymap_unavailable())
  end

  for _, direction in ipairs(mapping_order) do
    local key = mappings[direction]
    if key ~= false and type(key) ~= "string" then
      return result.err(errors.mapping_key(direction))
    end

    if type(key) == "string" and key ~= "" then
      local registered, registration_error = pcall(vim.keymap.set, { "n", "x" }, key, callbacks[direction], {
        silent = true,
        desc = "Toss " .. direction,
      })
      if not registered then
        return result.err(errors.mapping_registration(direction, registration_error))
      end
    end
  end

  return result.ok()
end

return M
