package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path
vim.opt.rtp:prepend(vim.fn.getcwd())

local test = require("tests.testlib")
local context = require("toss.context")

local root = vim.fn.getcwd()
local inside_path = root .. "/.toss-context-fixture"
local outside_path = vim.fn.tempname()

vim.fn.writefile({ "first line", "second line" }, inside_path)
vim.fn.writefile({ "outside project" }, outside_path)

local function edit(path)
  vim.cmd("edit " .. vim.fn.fnameescape(path))
end

local function assert_failure(message)
  local value, err = context.capture()
  test.equal(value, nil)
  test.truthy(type(err) == "string")
  if message then
    test.truthy(string.find(err, message, 1, true) ~= nil)
  end
end

test.describe("context capture", function()
  test.it("captures a normal file relative to the project root", function()
    edit(inside_path)
    vim.api.nvim_win_set_cursor(0, { 2, 0 })

    local value, err = context.capture()

    test.equal(err, nil)
    test.equal(value.path, ".toss-context-fixture")
    test.equal(value.start_line, nil)
    test.equal(value.end_line, nil)
  end)

  test.it("rejects an unnamed buffer", function()
    vim.cmd("enew")
    assert_failure("no file path")
  end)

  test.it("rejects a special buffer", function()
    vim.cmd("enew")
    vim.bo.buftype = "nofile"
    assert_failure("not a file")
  end)

  test.it("rejects a file outside the project root", function()
    edit(outside_path)
    assert_failure("outside the project root")
  end)
end)

vim.fn.delete(inside_path)
vim.fn.delete(outside_path)
test.finish()
