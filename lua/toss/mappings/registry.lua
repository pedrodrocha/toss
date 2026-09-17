---@class TossMappingRegistry
---@field register fun(specifications: TossMappingSpecification[], run: fun(direction: TossDirection, origin: TossOrigin): boolean): TossResult<nil>

local errors = require("toss.errors")
local result = require("toss.result")
local M = {}

local modes = { "n", "x" }

local state = {
  installed_mappings = {},
  installed_run = nil,
  -- A failed mutation forces the next setup to retry instead of being a no-op.
  setup_dirty = false,
}

---@param mapping table
---@param mode string
---@return boolean
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

---@param mappings table[]
---@return TossError|nil
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

---@param specification TossMappingSpecification
---@param run fun(direction: TossDirection, origin: TossOrigin): boolean
---@return table
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

---@param specifications TossMappingSpecification[]
---@param run fun(direction: TossDirection, origin: TossOrigin): boolean
---@return boolean
local function matches_installed(specifications, run)
  if state.setup_dirty or state.installed_run ~= run or #state.installed_mappings ~= #specifications then
    return false
  end

  for index, specification in ipairs(specifications) do
    local mapping = state.installed_mappings[index]
    if mapping.name ~= specification.name or mapping.key ~= specification.key then
      return false
    end
  end
  return true
end

---@param specifications TossMappingSpecification[]
---@return TossError|nil
local function keymap_api_error(specifications)
  local set_available = type(vim) == "table" and type(vim.keymap) == "table" and type(vim.keymap.set) == "function"
  if #specifications > 0 and not set_available then
    return errors.keymap_unavailable()
  end
end

---@return TossError|nil
local function remove_installed_mappings()
  local removal_error = remove_mappings(state.installed_mappings)
  if removal_error then
    state.setup_dirty = true
    return removal_error
  end
end

---@param run fun(direction: TossDirection, origin: TossOrigin): boolean
local function begin_registration(run)
  state.installed_mappings = {}
  state.installed_run = run
  state.setup_dirty = false
end

---@param mappings table[]
---@param run fun(direction: TossDirection, origin: TossOrigin): boolean
---@return TossError|nil
local function rollback_registration(mappings, run)
  state.installed_mappings = mappings
  local cleanup_error = remove_mappings(mappings)
  state.installed_mappings = cleanup_error and mappings or {}
  state.installed_run = cleanup_error and run or nil
  state.setup_dirty = cleanup_error ~= nil
  return cleanup_error
end

---@param specifications TossMappingSpecification[]
---@param run fun(direction: TossDirection, origin: TossOrigin): boolean
---@return TossResult<table[]>
local function register_mappings(specifications, run)
  local new_mappings = {}
  for _, specification in ipairs(specifications) do
    local mapping = make_mapping(specification, run)
    local registered, registration_error = pcall(vim.keymap.set, modes, mapping.key, mapping.callback, mapping.options)
    if not registered then
      local cleanup_error = rollback_registration(new_mappings, run)
      local detail = tostring(registration_error)
      if cleanup_error then
        detail = detail .. "; cleanup failed: " .. errors.message(cleanup_error)
      end
      return result.err(errors.mapping_registration(specification.name, detail))
    end

    new_mappings[#new_mappings + 1] = mapping
  end

  return result.ok(new_mappings)
end

---@param specifications TossMappingSpecification[]
---@param run fun(direction: TossDirection, origin: TossOrigin): boolean
---@return TossResult<nil>
function M.register(specifications, run)
  if matches_installed(specifications, run) then
    return result.ok()
  end

  local api_error = keymap_api_error(specifications)
  if api_error then
    return result.err(api_error)
  end

  local removal_error = remove_installed_mappings()
  if removal_error then
    return result.err(removal_error)
  end

  begin_registration(run)
  local registered = register_mappings(specifications, run)
  if registered:is_err() then
    return registered
  end

  state.installed_mappings = registered.value
  return result.ok()
end

return M
