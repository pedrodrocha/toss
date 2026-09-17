---@class TossMappingConfigModule
---@field resolve fun(configured: boolean|TossMappings|nil): TossResult<TossMappingSpecification[]>

---@class TossMappingSpecification
---@field name string
---@field key string
---@field direction TossDirection
---@field origin TossOrigin
---@field description string

local definitions = require("toss.mappings.definitions")
local errors = require("toss.errors")
local result = require("toss.result")
local M = {}

---@param configured boolean|TossMappings|nil
---@return TossResult<TossMappings|nil>
local function parse_configuration(configured)
  if configured == nil or configured == false then
    return result.ok()
  end

  if configured == true then
    return result.ok({})
  end

  if type(configured) ~= "table" then
    return result.err(errors.mapping_configuration())
  end

  return result.ok(configured)
end

---@param definition TossMappingDefinition
---@param configured TossMappings
---@return string|false
local function resolve_key(definition, configured)
  local configured_key = configured[definition.name]
  if configured_key ~= nil then
    return configured_key
  end

  return definition.key
end

---@param definition TossMappingDefinition
---@param key any
---@return TossResult<TossMappingSpecification|nil>
local function resolve_definition(definition, key)
  if key ~= false and type(key) ~= "string" then
    return result.err(errors.mapping_key(definition.name))
  end

  if key == false or key == "" then
    return result.ok()
  end

  return result.ok({
    name = definition.name,
    direction = definition.direction,
    origin = definition.origin,
    key = key,
    description = definition.description,
  })
end

---@param configured TossMappings
---@return TossResult<TossMappingSpecification[]>
local function resolve_specifications(configured)
  local specifications = {}
  for _, definition in ipairs(definitions) do
    local resolved = resolve_definition(definition, resolve_key(definition, configured))
    if resolved:is_err() then
      return resolved
    end

    if resolved.value ~= nil then
      specifications[#specifications + 1] = resolved.value
    end
  end

  return result.ok(specifications)
end

---@param configured boolean|TossMappings|nil
---@return TossResult<TossMappingSpecification[]>
function M.resolve(configured)
  local parsed = parse_configuration(configured)
  if parsed:is_err() then
    return parsed
  end

  if parsed.value == nil then
    return result.ok({})
  end

  return resolve_specifications(parsed.value)
end

return M
