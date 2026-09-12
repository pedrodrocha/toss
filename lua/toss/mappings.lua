---@class TossMappingModule
---@field resolve fun(configured: boolean|TossMappings|nil): TossResult<TossMappings|nil>
---@field setup fun(configured: boolean|TossMappings|nil, callbacks: table<TossDirection, fun(): boolean>, yank_configured: boolean|TossMappings|nil, yank_callbacks: table<TossDirection, fun(): boolean>): TossResult<nil>

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
---@param prefix string
---@return TossResult<TossMappings|nil>
local function resolve_mappings(configured, prefix)
  local defaults = {}
  for _, mapping in ipairs(mapping_order) do
    defaults[mapping.direction] = prefix .. mapping.key
  end
  if configured == nil or configured == false then
    return result.ok()
  end

  if configured == true then
    return result.ok(defaults)
  end

  if type(configured) ~= "table" then
    return result.err(errors.mapping_configuration())
  end

  local mappings = {}
  for _, mapping in ipairs(mapping_order) do
    local direction = mapping.direction
    if configured[direction] == nil then
      mappings[direction] = defaults[direction]
    else
      mappings[direction] = configured[direction]
    end
  end

  return result.ok(mappings)
end

---@param configured boolean|TossMappings|nil
---@return TossResult<TossMappings|nil>
function M.resolve(configured)
  return resolve_mappings(configured, "<leader>t")
end

---@param mappings TossMappings|nil
---@param callbacks table<TossDirection, fun(): boolean>
---@param description_prefix string
---@return TossResult<nil>
local function register_mappings(mappings, callbacks, description_prefix)
  if mappings == nil then
    return result.ok()
  end

  if type(vim) ~= "table" or type(vim.keymap) ~= "table" or type(vim.keymap.set) ~= "function" then
    return result.err(errors.keymap_unavailable())
  end

  for _, mapping in ipairs(mapping_order) do
    local direction = mapping.direction
    local key = mappings[direction]
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
---@param yank_configured boolean|TossMappings|nil
---@param yank_callbacks table<TossDirection, fun(): boolean>|nil
---@return TossResult<nil>
function M.setup(configured, callbacks, yank_configured, yank_callbacks)
  local resolved = M.resolve(configured)
  if resolved.kind == "err" then
    return resolved
  end

  local normal_result = register_mappings(resolved.value, callbacks, "Toss ")
  if normal_result.kind == "err" then
    return normal_result
  end

  local resolved_yank = resolve_mappings(yank_configured, "<leader>ty")
  if resolved_yank.kind == "err" then
    return resolved_yank
  end

  return register_mappings(resolved_yank.value, yank_callbacks or {}, "Toss yank ")
end

return M
