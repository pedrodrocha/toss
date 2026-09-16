---@class TossFormatter
---@field format fun(ctx: TossContext|nil): TossResult<string>

local reference = require("toss.formatter.reference")
local M = {}

---@param ctx TossContext|nil
---@return TossResult<string>
function M.format(ctx)
  return reference.format(ctx)
end

return M
