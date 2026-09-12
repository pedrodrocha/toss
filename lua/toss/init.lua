local context = require("toss.context")
local formatter = require("toss.formatter")
local transports = require("toss.transports")

local M = {
  config = {},
}

local mapping_order = { "left", "down", "up", "right" }
local default_mappings = {
  left = "<leader>th",
  down = "<leader>tj",
  up = "<leader>tk",
  right = "<leader>tl",
}

local function notify(message)
  if type(vim) == "table" and type(vim.notify) == "function" then
    local level = vim.log and vim.log.levels and vim.log.levels.INFO or nil
    vim.notify("toss: " .. message, level)
  end
end

local function resolve_mappings()
  local configured = M.config.mappings

  if configured == nil or configured == false then
    return nil
  end

  if configured == true then
    return default_mappings
  end

  if type(configured) ~= "table" then
    notify("mappings must be true or a table")
    return nil
  end

  local mappings = {}
  for _, direction in ipairs(mapping_order) do
    if configured[direction] == nil then
      mappings[direction] = default_mappings[direction]
    else
      mappings[direction] = configured[direction]
    end
  end

  return mappings
end

local function setup_mappings()
  local mappings = resolve_mappings()
  if not mappings then
    return
  end

  if type(vim) ~= "table" or type(vim.keymap) ~= "table" or type(vim.keymap.set) ~= "function" then
    notify("keymap API is unavailable")
    return
  end

  for _, direction in ipairs(mapping_order) do
    local key = mappings[direction]
    if key ~= false and type(key) == "string" and key ~= "" then
      vim.keymap.set({ "n", "x" }, key, M[direction], {
        silent = true,
        desc = "Toss " .. direction,
      })
    end
  end
end

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

  setup_mappings()

  return M
end

local function resolve_transport()
  local configured = M.config.transport

  if type(configured) == "string" then
    local transport_name = configured
    local transport, transport_error = transports.resolve(transport_name)
    if not transport then
      return nil, transport_error
    end

    configured = transport
  end

  if type(configured) ~= "table" then
    return nil, "transport is not configured"
  end

  if type(configured.send) ~= "function" then
    return nil, "transport must provide send(direction, text)"
  end

  return configured
end

local function run(direction)
  local transport, transport_error = resolve_transport()
  if not transport then
    notify(transport_error)
    return false
  end

  local capture_ok, captured, capture_error = pcall(context.capture)
  if not capture_ok then
    notify("context capture failed: " .. tostring(captured))
    return false
  end

  if not captured then
    notify(capture_error or "could not capture context")
    return false
  end

  local format_ok, payload, format_error = pcall(formatter.format, captured)
  if not format_ok then
    notify("context formatting failed: " .. tostring(payload))
    return false
  end

  if not payload then
    notify(format_error or "could not format context")
    return false
  end

  local send_ok, sent, send_error = pcall(transport.send, direction, payload)
  if not send_ok then
    notify("transport failed: " .. tostring(sent))
    return false
  end

  if sent == false or (sent == nil and send_error ~= nil) then
    notify(send_error or "transport failed")
    return false
  end

  return true
end

function M.left()
  return run("left")
end

function M.down()
  return run("down")
end

function M.up()
  return run("up")
end

function M.right()
  return run("right")
end

return M
