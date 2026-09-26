---@type TossContextFormatter<TossTextContext>
local M = {}

local result = require("toss.result")

---@param ctx TossTextContext
---@return TossResult<string>
function M.format(ctx)
  return result.ok(ctx.text)
end

return M
