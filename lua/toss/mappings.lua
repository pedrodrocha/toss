---@class TossMappingModule
---@field setup fun(configured: boolean|TossMappings|nil, run: fun(direction: TossDirection, source: TossContextSource): boolean): TossResult<nil>

local errors = require("toss.errors")
local result = require("toss.result")
local M = {}

local directions = {
  { name = "left", key = "h" },
  { name = "down", key = "j" },
  { name = "up", key = "k" },
  { name = "right", key = "l" },
}

local mapping_contexts = {
  { name = "", source = "file", prefix = "<leader>t", description = "Toss " },
  { name = "yank_", source = "register", prefix = "<leader>ty", description = "Toss yank " },
}

---@param configured boolean|TossMappings|nil
---@param run fun(direction: TossDirection, source: TossContextSource): boolean
---@return TossResult<nil>
function M.setup(configured, run)
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

  for _, context in ipairs(mapping_contexts) do
    for _, direction in ipairs(directions) do
      local name = context.name .. direction.name
      local key = configured[name]
      if key == nil then
        key = context.prefix .. direction.key
      end

      if key ~= false and type(key) ~= "string" then
        return result.err(errors.mapping_key(name))
      end

      if type(key) == "string" and key ~= "" then
        local registered, registration_error = pcall(vim.keymap.set, { "n", "x" }, key, function()
          return run(direction.name, context.source)
        end, {
          silent = true,
          desc = context.description .. direction.name,
        })
        if not registered then
          return result.err(errors.mapping_registration(name, registration_error))
        end
      end
    end
  end

  return result.ok()
end

return M
