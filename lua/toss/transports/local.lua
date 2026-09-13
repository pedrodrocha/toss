local result = require("toss.result")

---@class TossLocalCall
---@field operation "send"|"focus"
---@field direction TossDirection
---@field text string|nil

---@class TossLocalTransport
---@field private _calls TossLocalCall[]
---@field available fun(self: TossLocalTransport): boolean
---@field send fun(self: TossLocalTransport, direction: TossDirection, text: string): TossResult<nil>
---@field focus fun(self: TossLocalTransport, direction: TossDirection): TossResult<nil>
---@field calls fun(): TossLocalCall[]
---@field reset fun()

local LocalTransport = {}
LocalTransport.__index = LocalTransport

local function notify(direction, text)
  local message = "toss: local transport would send " .. direction .. ": " .. text

  if type(vim) ~= "table" then
    return
  end

  if type(vim.notify) == "function" then
    local level = vim.log and vim.log.levels and vim.log.levels.INFO
    vim.notify(message, level)
    return
  end

  if vim.api and type(vim.api.nvim_echo) == "function" then
    vim.api.nvim_echo({ { message, "MoreMsg" } }, true, {})
  end
end

local function copy_calls(calls)
  local copied = {}
  for index, call in ipairs(calls) do
    copied[index] = {
      operation = call.operation,
      direction = call.direction,
      text = call.text,
    }
  end
  return copied
end

---@return TossLocalTransport
function LocalTransport.new()
  return setmetatable({ _calls = {} }, LocalTransport)
end

---@return boolean
function LocalTransport:available()
  return true
end

---@param direction TossDirection
---@param text string
---@return TossResult<nil>
function LocalTransport:send(direction, text)
  self._calls[#self._calls + 1] = {
    operation = "send",
    direction = direction,
    text = text,
  }
  notify(direction, text)
  return result.ok()
end

---@param direction TossDirection
---@return TossResult<nil>
function LocalTransport:focus(direction)
  self._calls[#self._calls + 1] = {
    operation = "focus",
    direction = direction,
  }
  return result.ok()
end

---@return TossLocalCall[]
function LocalTransport:calls()
  return copy_calls(self._calls)
end

function LocalTransport:reset()
  self._calls = {}
end

local singleton = LocalTransport.new()

---@class TossLocalTransportModule : TossTransport
---@field available fun(): boolean
---@field send fun(direction: TossDirection, text: string): TossResult<nil>
---@field focus fun(direction: TossDirection): TossResult<nil>
---@field calls fun(): TossLocalCall[]
---@field reset fun()

---@type TossLocalTransportModule
local M = {
  available = function()
    return singleton:available()
  end,
  send = function(direction, text)
    return singleton:send(direction, text)
  end,
  focus = function(direction)
    return singleton:focus(direction)
  end,
  calls = function()
    return singleton:calls()
  end,
  reset = function()
    singleton:reset()
  end,
}

return M
