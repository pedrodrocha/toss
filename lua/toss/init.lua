local M = {
  config = {},
}

local function notify(message)
  if vim and vim.notify then
    local level = vim.log and vim.log.levels and vim.log.levels.INFO or nil
    vim.notify("toss: " .. message, level)
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

  return M
end

local function not_implemented()
  notify("not implemented yet")
  return false
end

function M.left()
  return not_implemented()
end

function M.down()
  return not_implemented()
end

function M.up()
  return not_implemented()
end

function M.right()
  return not_implemented()
end

return M
