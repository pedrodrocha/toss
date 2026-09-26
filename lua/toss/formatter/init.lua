---@class TossContextFormatter<TContext>
---@field format fun(ctx: TContext): TossResult<string>

local reference = require("toss.formatter.reference")
---@type TossContextFormatter<TossContext>
local M = {}

---@param ctx TossContext
---@return TossResult<string>
function M.format(ctx)
  return reference.format(ctx)
end

return M
