package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path
vim.opt.rtp:prepend(vim.fn.getcwd())

local test = require("tests.testlib")
local context = require("toss.context")
local project_root = require("toss.context.project_root")

local root = vim.fn.getcwd()
local inside_path = root .. "/.toss-context-fixture"
local repository_root = root .. "/.toss-context-repository"
local repository_path = repository_root .. "/nested.txt"
local marker_root = vim.fn.tempname()
local marker_path = marker_root .. "/src/marker.txt"
local fallback_root = vim.fn.tempname()
local fallback_path = fallback_root .. "/fallback.txt"
local outside_path = vim.fn.tempname()

vim.fn.writefile({ "first line", "second line" }, inside_path)
vim.fn.mkdir(repository_root .. "/.git", "p")
vim.fn.writefile({ "nested repository" }, repository_path)
vim.fn.mkdir(marker_root .. "/src", "p")
vim.fn.writefile({ "{}" }, marker_root .. "/package.json")
vim.fn.writefile({ "package marker" }, marker_path)
vim.fn.mkdir(fallback_root, "p")
vim.fn.writefile({ "working directory fallback" }, fallback_path)
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

  test.it("prefers the .git ancestor over the working directory", function()
    edit(repository_path)

    local value, err = context.capture()

    test.equal(err, nil)
    test.equal(value.path, "nested.txt")
  end)

  test.it("uses a package marker before the working directory", function()
    edit(marker_path)

    local value, err = context.capture()

    test.equal(err, nil)
    test.equal(value.path, "src/marker.txt")
  end)

  test.it("uses the working directory when no configured marker exists", function()
    local original_directory = vim.fn.getcwd()
    vim.cmd("lcd " .. vim.fn.fnameescape(fallback_root))
    edit(fallback_path)

    local value, err = context.capture()

    vim.cmd("lcd " .. vim.fn.fnameescape(original_directory))

    test.equal(err, nil)
    test.equal(value.path, "fallback.txt")
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

  test.it("uses an absolute path for a file outside the project root", function()
    edit(outside_path)

    local value, err = context.capture()

    test.equal(err, nil)
    test.equal(value.path, outside_path)
    test.equal(value.start_line, nil)
    test.equal(value.end_line, nil)
  end)

  test.it("uses an absolute path when no project root is resolved", function()
    edit(inside_path)

    local previous_resolve = project_root.resolve
    project_root.resolve = function()
      return nil
    end

    local value, err = context.capture()

    project_root.resolve = previous_resolve

    test.equal(err, nil)
    test.equal(value.path, inside_path)
  end)
end)

vim.fn.delete(inside_path)
vim.fn.delete(repository_root, "rf")
vim.fn.delete(marker_root, "rf")
vim.fn.delete(fallback_root, "rf")
vim.fn.delete(outside_path)
test.finish()
