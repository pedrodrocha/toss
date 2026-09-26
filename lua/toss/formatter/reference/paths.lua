---@type TossContextFormatter<TossFileContext|TossDirectoryContext|TossPathSetContext>
local M = {}

local errors = require("toss.errors")
local result = require("toss.result")

---@param ctx TossFileContext
---@return TossResult<string>
local function format_file(ctx)
  if ctx.start_line == nil and ctx.end_line == nil then
    return result.ok("@" .. ctx.path)
  end

  return result.ok(string.format("@%s#L%d-L%d", ctx.path, ctx.start_line, ctx.end_line))
end

---@param ctx TossDirectoryContext
---@return TossResult<string>
local function format_directory(ctx)
  local path = ctx.path:gsub("/+$", "") .. "/"
  return result.ok("@" .. path)
end

---@param ctx TossPathSetContext
---@return TossResult<string>
local function format_path_set(ctx)
  local references = {}
  for index, item in ipairs(ctx.items) do
    local formatted
    if item.kind == "file" then
      formatted = format_file(item)
    else
      formatted = format_directory(item)
    end

    references[index] = formatted.value
  end

  return result.ok(table.concat(references, " "))
end

---@param ctx TossFileContext|TossDirectoryContext|TossPathSetContext
---@return TossResult<string>
function M.format(ctx)
  if ctx.kind == "file" then
    return format_file(ctx)
  end

  if ctx.kind == "directory" then
    return format_directory(ctx)
  end

  if ctx.kind == "path_set" then
    return format_path_set(ctx)
  end

  return result.err(errors.context_formatting("unsupported path context kind: " .. tostring(ctx.kind)))
end

return M
