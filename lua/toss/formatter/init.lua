---@class TossFormatter
---@field format fun(ctx: TossContext): TossResult<string>

local reference = require("toss.formatter.reference")
local M = {}

---@param ctx TossContext
---@return TossResult<string>
function M.format(ctx)
  return reference.format(ctx)
end

return M
