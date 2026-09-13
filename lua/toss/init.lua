local context = require("toss.context")
local errors = require("toss.errors")
local mappings = require("toss.mappings")
local runner = require("toss.runner")
local which_key = require("toss.which_key")

---@alias TossDirection "left"|"down"|"up"|"right"

---@class TossMappings
---@field left string|false|nil
---@field down string|false|nil
---@field up string|false|nil
---@field right string|false|nil
---@field yank_left string|false|nil
---@field yank_down string|false|nil
---@field yank_up string|false|nil
---@field yank_right string|false|nil

---@class TossTransport
---@field send fun(direction: TossDirection, text: string): TossResult<nil>
---@field focus fun(direction: TossDirection): TossResult<nil>
---@field available fun(): boolean

---@class TossConfig
---@field mappings boolean|TossMappings|nil
---@field which_key boolean|nil
---@field transport string|TossTransport|nil
---@field [string] any

---@class Toss
---@field config TossConfig
---@field setup fun(opts: TossSetupOptions|nil): Toss
---@field left fun(origin: TossOrigin|nil): boolean
---@field down fun(origin: TossOrigin|nil): boolean
---@field up fun(origin: TossOrigin|nil): boolean
---@field right fun(origin: TossOrigin|nil): boolean

---@class TossSetupOptions
---@field mappings boolean|TossMappings|nil
---@field which_key boolean|nil
---@field transport string|TossTransport|nil

local M = {
  ---@type TossConfig
  config = {},
}

---@param err TossError
local function notify(err)
  if type(vim) ~= "table" or type(vim.notify) ~= "function" then
    return
  end

  local notification_level
  local level_name = string.upper(errors.level(err))
  if vim.log and vim.log.levels then
    notification_level = vim.log.levels[level_name]
  end

  vim.notify("toss: " .. errors.message(err), notification_level)
end

---@param direction TossDirection
---@param origin TossOrigin|nil
---@return boolean
local function run(direction, origin)
  if origin == nil then
    origin = "file_buffer"
  end

  local run_result = runner.run(direction, origin, M.config)
  if run_result:is_err() then
    notify(run_result.error)
  end

  return run_result:is_ok()
end

---@param opts TossSetupOptions|nil
---@return Toss
function M.setup(opts)
  if opts == nil then
    opts = {}
  end

  if type(opts) ~= "table" then
    notify(errors.setup_options())
    return M
  end

  local previous_mappings = M.config.mappings
  for key, value in pairs(opts) do
    M.config[key] = value
  end

  local context_result = context.setup()
  if context_result:is_err() then
    notify(context_result.error)
  end

  local mappings_result = mappings.setup(M.config.mappings, run)
  if mappings_result:is_err() then
    -- Mapping setup is transactional. Keep the configuration in sync with the
    -- mappings that are still active when validation or registration fails.
    M.config.mappings = previous_mappings
    notify(mappings_result.error)
  end

  local which_key_result = which_key.setup(M.config.which_key)
  if which_key_result:is_err() then
    notify(which_key_result.error)
  end

  return M
end

---@param origin TossOrigin|nil
---@return boolean
function M.left(origin)
  return run("left", origin)
end

---@param origin TossOrigin|nil
---@return boolean
function M.down(origin)
  return run("down", origin)
end

---@param origin TossOrigin|nil
---@return boolean
function M.up(origin)
  return run("up", origin)
end

---@param origin TossOrigin|nil
---@return boolean
function M.right(origin)
  return run("right", origin)
end

return M
