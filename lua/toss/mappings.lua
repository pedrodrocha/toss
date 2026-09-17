---@class TossMappingModule
---@field setup fun(configured: boolean|TossMappings|nil, run: fun(direction: TossDirection, origin: TossOrigin): boolean): TossResult<nil>

local config = require("toss.mappings.config")
local errors = require("toss.errors")
local result = require("toss.result")
local M = {}

local modes = { "n", "x" }

local installed_mappings = {}
local installed_run
-- A failed mutation forces the next setup to retry instead of being a no-op.
local setup_dirty = false

local function is_owned(mapping, mode)
  if type(vim) ~= "table" or type(vim.fn) ~= "table" or type(vim.fn.maparg) ~= "function" then
    return true
  end

  local queried, current = pcall(vim.fn.maparg, mapping.key, mode, false, true)
  if not queried then
    return true
  end

  return type(current) == "table" and next(current) ~= nil and current.callback == mapping.callback
end

local function remove_mappings(mappings)
  if #mappings == 0 then
    return nil
  end
  if type(vim) ~= "table" or type(vim.keymap) ~= "table" or type(vim.keymap.del) ~= "function" then
    return errors.keymap_delete_unavailable()
  end

  for _, mapping in ipairs(mappings) do
    for _, mode in ipairs(modes) do
      if is_owned(mapping, mode) then
        local removed, remove_error = pcall(vim.keymap.del, mode, mapping.key)
        if not removed then
          return errors.mapping_removal(mapping.name, remove_error)
        end
      end
    end
  end
end

local function make_mapping(specification, run)
  local callback = function()
    return run(specification.direction, specification.origin)
  end
  return {
    name = specification.name,
    key = specification.key,
    callback = callback,
    options = {
      silent = true,
      desc = specification.description,
    },
  }
end

local function matches_installed(specifications, run)
  if setup_dirty or installed_run ~= run or #installed_mappings ~= #specifications then
    return false
  end

  for index, specification in ipairs(specifications) do
    local mapping = installed_mappings[index]
    if mapping.name ~= specification.name or mapping.key ~= specification.key then
      return false
    end
  end
  return true
end

---@param configured boolean|TossMappings|nil
---@param run fun(direction: TossDirection, origin: TossOrigin): boolean
---@return TossResult<nil>
function M.setup(configured, run)
  local resolved = config.resolve(configured)
  if resolved:is_err() then
    return resolved
  end

  local specifications = resolved.value
  if matches_installed(specifications, run) then
    return result.ok()
  end

  local set_available = type(vim) == "table" and type(vim.keymap) == "table" and type(vim.keymap.set) == "function"
  if #specifications > 0 and not set_available then
    return result.err(errors.keymap_unavailable())
  end

  local removal_error = remove_mappings(installed_mappings)
  if removal_error then
    setup_dirty = true
    return result.err(removal_error)
  end

  installed_mappings = {}
  installed_run = run
  setup_dirty = false

  local new_mappings = {}
  for _, specification in ipairs(specifications) do
    local mapping = make_mapping(specification, run)
    local registered, registration_error = pcall(vim.keymap.set, modes, mapping.key, mapping.callback, mapping.options)
    if not registered then
      installed_mappings = new_mappings
      local cleanup_error = remove_mappings(new_mappings)
      installed_mappings = cleanup_error and new_mappings or {}
      installed_run = cleanup_error and run or nil
      setup_dirty = cleanup_error ~= nil

      local detail = tostring(registration_error)
      if cleanup_error then
        detail = detail .. "; cleanup failed: " .. errors.message(cleanup_error)
      end
      return result.err(errors.mapping_registration(specification.name, detail))
    end

    new_mappings[#new_mappings + 1] = mapping
  end

  installed_mappings = new_mappings
  return result.ok()
end

return M
