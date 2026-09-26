---@type TossContextFormatter<TossContext>
local M = {}

local errors = require("toss.errors")
local paths = require("toss.formatter.reference.paths")
local text = require("toss.formatter.reference.text")
local diagnostic = require("toss.formatter.reference.diagnostic")
local result = require("toss.result")

---@param ctx TossContext
---@return TossResult<string>
function M.format(ctx)
  if type(ctx) ~= "table" then
    return result.err(errors.invalid_context())
  end

  if ctx.kind == "file" or ctx.kind == "directory" or ctx.kind == "path_set" then
    return paths.format(ctx)
  end

  if ctx.kind == "text" then
    return text.format(ctx)
  end

  if ctx.kind == "diagnostic" or ctx.kind == "diagnostic_set" then
    return diagnostic.format(ctx)
  end

  return result.err(errors.context_formatting("unsupported context kind: " .. tostring(ctx.kind)))
end

return M
