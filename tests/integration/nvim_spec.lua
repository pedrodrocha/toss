package.path = "./?.lua;./?/init.lua;" .. package.path

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

vim.fn.delete(fixture_dir, "rf")
test.finish()
