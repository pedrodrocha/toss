local context_register = require("toss.context.register")
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
---@field available? fun(): boolean

---@class TossConfig
---@field mappings boolean|TossMappings|nil
---@field which_key boolean|nil
---@field transport string|TossTransport|nil
---@field [string] any

---@class Toss
---@field config TossConfig
---@field setup fun(opts: TossSetupOptions|nil): Toss
---@field left fun(source: TossContextSource|nil): boolean
---@field down fun(source: TossContextSource|nil): boolean
---@field up fun(source: TossContextSource|nil): boolean
---@field right fun(source: TossContextSource|nil): boolean

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
---@param source TossContextSource|nil
---@return boolean
local function run(direction, source)
  source = source or "file"
  local run_result = runner.run(direction, source, M.config)
  if run_result.kind == "err" then
    notify(run_result.error)
  end

  return run_result.kind == "ok"
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

  for key, value in pairs(opts) do
    M.config[key] = value
  end

  local register_result = context_register.setup()
  if register_result.kind == "err" then
    notify(register_result.error)
  end

  local mappings_result = mappings.setup(M.config.mappings, run)
  if mappings_result.kind == "err" then
    notify(mappings_result.error)
  end

  local which_key_result = which_key.setup(M.config.which_key)
  if which_key_result.kind == "err" then
    notify(which_key_result.error)
  end

  return M
end

---@param source TossContextSource|nil
---@return boolean
function M.left(source)
  return run("left", source)
end

---@param source TossContextSource|nil
---@return boolean
function M.down(source)
  return run("down", source)
end

---@param source TossContextSource|nil
---@return boolean
function M.up(source)
  return run("up", source)
end

---@param source TossContextSource|nil
---@return boolean
function M.right(source)
  return run("right", source)
end

return M
