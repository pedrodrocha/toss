---@class TossFileContext
---@field kind "file"
---@field path string
---@field start_line integer|nil
---@field end_line integer|nil

---@class TossTextContext
---@field kind "text"
---@field text string

---@class TossDirectoryContext
---@field kind "directory"
---@field path string

---@alias TossPathContext TossFileContext|TossDirectoryContext

---@class TossPathSetContext
---@field kind "path_set"
---@field items TossPathContext[]

---@alias TossContext TossFileContext|TossTextContext|TossDirectoryContext|TossPathSetContext

---@alias TossOrigin "file_buffer"|"yank"

---@class TossContextModule
---@field setup fun(): TossResult<nil>
---@field capture fun(origin: TossOrigin|nil): TossResult<TossContext>

local errors = require("toss.errors")
local file_buffer = require("toss.context.origin.file_buffer")
local result = require("toss.result")
local yank = require("toss.context.origin.yank")
local M = {}

---@return TossResult<nil>
function M.setup()
  return yank.setup()
end

---@param origin TossOrigin|nil
---@return TossResult<TossContext>
function M.capture(origin)
  if origin == nil or origin == "file_buffer" then
    return file_buffer.capture()
  end

  if origin == "yank" then
    return yank.capture()
  end

  return result.err(errors.invalid_context_origin(origin))
end

return M
