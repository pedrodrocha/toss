---@class TossMappingModule
---@field setup fun(configured: boolean|TossMappings|nil, run: fun(direction: TossDirection, origin: TossOrigin): boolean): TossResult<nil>

local config = require("toss.mappings.config")
local registry = require("toss.mappings.registry")
local M = {}

---@param configured boolean|TossMappings|nil
---@param run fun(direction: TossDirection, origin: TossOrigin): boolean
---@return TossResult<nil>
function M.setup(configured, run)
  local resolved = config.resolve(configured)
  if resolved:is_err() then
    return resolved
  end

  return registry.register(resolved.value, run)
end

return M
