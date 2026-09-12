local mappings = require("toss.mappings")
local runner = require("toss.runner")

---@alias TossDirection "left"|"down"|"up"|"right"

---@class TossMappings
---@field left string|false|nil
---@field down string|false|nil
---@field up string|false|nil
---@field right string|false|nil

---@class TossTransport
---@field send fun(direction: TossDirection, text: string): boolean, string|nil
---@field available? fun(): boolean

---@class TossConfig
---@field mappings boolean|TossMappings|nil
---@field transport string|TossTransport|nil

---@class Toss
---@field config TossConfig
---@field setup fun(opts: TossSetupOptions|nil): Toss
---@field left fun(): boolean
---@field down fun(): boolean
---@field up fun(): boolean
---@field right fun(): boolean

---@class TossSetupOptions
---@field mappings boolean|TossMappings|nil
---@field transport string|TossTransport|nil

---@type Toss
local M = {
  config = {},
}

local function notify(message)
  if type(vim) == "table" and type(vim.notify) == "function" then
    local level = vim.log and vim.log.levels and vim.log.levels.INFO or nil
    vim.notify("toss: " .. message, level)
  end
end

---@param opts TossSetupOptions|nil
---@return Toss
function M.setup(opts)
  if opts == nil then
    opts = {}
  end

  if type(opts) ~= "table" then
    notify("setup options must be a table")
    return M
  end

  for key, value in pairs(opts) do
    M.config[key] = value
  end

  local mappings_ok, mappings_error = mappings.setup(M.config.mappings, M)
  if not mappings_ok then
    notify(mappings_error)
  end

  return M
end

---@param direction TossDirection
---@return boolean
local function run(direction)
  local ok, err = runner.run(direction, M.config)
  if not ok then
    notify(err)
  end

  return ok
end

---@return boolean
function M.left()
  return run("left")
end

---@return boolean
function M.down()
  return run("down")
end

---@return boolean
function M.up()
  return run("up")
end

---@return boolean
function M.right()
  return run("right")
end

return M
