---@class TossYankContextModule
---@field setup fun(): TossResult<nil>
---@field capture fun(): TossResult<TossContext>

local observer = require("toss.context.yank.observer")
local result = require("toss.result")

local M = {}

---@return TossResult<TossContext>
function M.capture()
  local register_result = observer.current()
  if register_result:is_err() then
    return register_result
  end

  local register = register_result.value
  if register.path ~= nil and register.start_line ~= nil and register.end_line ~= nil then
    return result.ok({
      kind = "file",
      path = register.path,
      start_line = register.start_line,
      end_line = register.end_line,
    })
  end

  return result.ok({ kind = "text", text = register.text })
end

---@return TossResult<nil>
function M.setup()
  return observer.setup()
end

return M
