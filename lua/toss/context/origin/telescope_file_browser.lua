local api = require("toss.telescope.api")
local errors = require("toss.errors")
local path = require("toss.context.path")
local result = require("toss.result")

local M = {}

-- File-browser selection ----------------------------------------------------

---@param value any
---@param field string
---@return any
local function safe_field(value, field)
  if value == nil then
    return nil
  end

  local ok, field_value = pcall(function()
    return value[field]
  end)
  if ok then
    return field_value
  end

  return nil
end

---@param picker table
---@return boolean
local function is_file_browser_picker(picker)
  local finder = safe_field(picker, "finder")
  if finder == nil then
    return false
  end

  local browse_files = safe_field(finder, "_browse_files")
  local browse_folders = safe_field(finder, "_browse_folders")
  return (browse_files ~= nil and browse_files ~= false) or (browse_folders ~= nil and browse_folders ~= false)
end

---@return TossResult<table[]>
local function selected_entries()
  local picker_result = api.active_picker()
  if picker_result:is_err() then
    return result.err(picker_result.error)
  end

  local picker = picker_result.value
  if not is_file_browser_picker(picker) then
    return result.err(errors.telescope_file_browser_picker())
  end

  local selection_result = api.multi_selection(picker)
  if selection_result:is_err() then
    return result.err(selection_result.error)
  end

  if type(selection_result.value) ~= "table" then
    return result.err(errors.telescope_selection())
  end

  local entries = selection_result.value
  if #entries == 0 then
    local cursor_result = api.cursor_entry()
    if cursor_result:is_err() then
      return result.err(cursor_result.error)
    end

    entries = { cursor_result.value }
  end

  return result.ok(entries)
end

-- File-browser entry to Toss context mapping -------------------------------

---@param value any
---@return string|nil
local function absolute_string(value)
  if type(value) ~= "string" or value == "" then
    return nil
  end

  if value:sub(1, 1) == "/" or value:match("^%a:[/\\]") or value:match("^\\\\") then
    return value
  end

  return nil
end

---@param path_object any
---@return string|nil
local function path_object_absolute(path_object)
  if path_object == nil then
    return nil
  end

  local ok, absolute_path = pcall(function()
    return path_object:absolute()
  end)
  if ok then
    return absolute_string(absolute_path)
  end

  return nil
end

---@param entry table
---@return string|nil, any
local function entry_absolute_path(entry)
  for _, field in ipairs({ "absolute_path", "path", "value" }) do
    local absolute_path = absolute_string(safe_field(entry, field))
    if absolute_path then
      return absolute_path, safe_field(entry, "Path")
    end
  end

  local path_object = safe_field(entry, "Path")
  return path_object_absolute(path_object), path_object
end

---@param entry table
---@return boolean|nil
local function entry_directory_metadata(entry)
  for _, field in ipairs({ "is_directory", "is_dir" }) do
    local value = safe_field(entry, field)
    if type(value) == "boolean" then
      return value
    end
  end

  for _, field in ipairs({ "stat", "lstat" }) do
    local stat = safe_field(entry, field)
    local stat_type = safe_field(stat, "type")
    if stat_type == "directory" then
      return true
    end
    if type(stat_type) == "string" then
      return false
    end
  end

  return nil
end

---@param path_object any
---@return boolean|nil
local function path_object_is_directory(path_object)
  if path_object == nil then
    return nil
  end

  local ok, is_directory = pcall(function()
    return path_object:is_dir()
  end)
  if ok and type(is_directory) == "boolean" then
    return is_directory
  end

  return nil
end

---@param entry table
---@return TossResult<TossPathContext>
local function map_entry(entry)
  if type(entry) ~= "table" then
    return result.err(errors.telescope_file_browser_entry())
  end

  local absolute_path, path_object = entry_absolute_path(entry)
  if not absolute_path then
    return result.err(errors.telescope_file_browser_entry())
  end

  local is_directory = entry_directory_metadata(entry)
  if is_directory == nil then
    is_directory = path_object_is_directory(path_object)
  end
  if is_directory == nil then
    is_directory = path.is_directory(absolute_path)
  end

  return result.ok({
    kind = is_directory and "directory" or "file",
    path = path.relative_or_absolute(absolute_path),
  })
end

---@param entries table[]
---@return TossResult<TossPathContext|TossPathSetContext>
local function map_entries(entries)
  if type(entries) ~= "table" then
    return result.err(errors.telescope_selection())
  end

  local items = {}
  local seen = {}

  for _, entry in ipairs(entries) do
    local mapped_result = map_entry(entry)
    if mapped_result:is_err() then
      return result.err(mapped_result.error)
    end

    local item = mapped_result.value
    local key = item.kind .. "\0" .. item.path
    if not seen[key] then
      seen[key] = true
      items[#items + 1] = item
    end
  end

  if #items == 0 then
    return result.err(errors.telescope_selection())
  end

  if #items == 1 then
    return result.ok(items[1])
  end

  return result.ok({
    kind = "path_set",
    items = items,
  })
end

-- Public API ----------------------------------------------------------------

---@return TossResult<TossPathContext|TossPathSetContext>
function M.capture()
  local entries_result = selected_entries()
  if entries_result:is_err() then
    return result.err(entries_result.error)
  end

  return map_entries(entries_result.value)
end

return M
