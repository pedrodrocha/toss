package.path = "./?.lua;./?/init.lua;" .. package.path
vim.opt.rtp:prepend(vim.fn.getcwd())

local test = require("tests.testlib")

local fixture_dir = vim.fn.tempname()
local fixture_path = fixture_dir .. "/fixture.txt"
vim.fn.mkdir(fixture_dir, "p")
vim.fn.writefile({ "first line", "second line" }, fixture_path)

vim.cmd("edit " .. vim.fn.fnameescape(fixture_path))

test.run("headless Neovim loads a fixture file", function()
  test.equal(vim.api.nvim_buf_get_name(0), fixture_path)
  test.equal(vim.api.nvim_buf_line_count(0), 2)
  test.equal(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1], "first line")
end)

test.run("public direction stubs notify in Neovim", function()
  local toss = require("toss")
  local notifications = {}
  local previous_notify = vim.notify
  vim.notify = function(message, level)
    notifications[#notifications + 1] = { message = message, level = level }
  end

  local results = {
    toss.left(),
    toss.down(),
    toss.up(),
    toss.right(),
  }

  vim.notify = previous_notify

  for _, result in ipairs(results) do
    test.equal(result, false)
  end

  test.equal(#notifications, 4)
  for _, notification in ipairs(notifications) do
    test.equal(notification.message, "toss: not implemented yet")
    test.equal(notification.level, vim.log.levels.INFO)
  end

  test.equal(vim.fn.maparg("<leader>th", "n"), "")
  test.equal(vim.fn.maparg("<leader>tj", "n"), "")
  test.equal(vim.fn.maparg("<leader>tk", "n"), "")
  test.equal(vim.fn.maparg("<leader>tl", "n"), "")
end)

vim.fn.delete(fixture_dir, "rf")
test.finish()
