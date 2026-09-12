package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path
vim.opt.rtp:prepend(vim.fn.getcwd())

local test = require("tests.testlib")
local errors = require("toss.errors")
local context = require("toss.context")
local project_root = require("toss.context.root")

local root = vim.fn.getcwd()
local inside_path = root .. "/.toss-context-fixture"
local visual_path = root .. "/.toss-visual-fixture"
local repository_root = root .. "/.toss-context-repository"
local repository_path = repository_root .. "/nested.txt"
local marker_root = vim.fn.tempname()
local marker_path = marker_root .. "/src/marker.txt"
local fallback_root = vim.fn.tempname()
local fallback_path = fallback_root .. "/fallback.txt"
local outside_path = vim.fn.tempname()

vim.fn.writefile({ "first line", "second line" }, inside_path)
vim.fn.writefile({ "one", "two", "three", "four", "five" }, visual_path)
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

local function capture_success()
  local capture_result = context.capture()

  test.equal(capture_result.kind, "ok")
  return assert(capture_result.value)
end

local function assert_failure(message)
  local capture_result = context.capture()

  test.equal(capture_result.kind, "err")
  local err = capture_result.error
  test.truthy(errors.is(err))
  if type(message) == "string" then
    test.truthy(string.find(errors.message(err), message, 1, true) ~= nil)
  end
end

local function leave_visual_mode()
  local escape = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(escape, "nx", false)
end

local function capture_selection(keys)
  edit(visual_path)
  vim.cmd("normal! " .. keys)
  local capture_result = context.capture()
  leave_visual_mode()
  return capture_result
end

test.describe("context capture", function()
  test.it("rejects an unknown context mode", function()
    local capture_result = context.capture("other")

    test.equal(capture_result.kind, "err")
    test.equal(errors.message(capture_result.error), "context mode must be \"file\" or \"yank\": other")
  end)

  test.it("captures a normal file relative to the project root", function()
    edit(inside_path)
    vim.api.nvim_win_set_cursor(0, { 2, 0 })

    local value = capture_success()

    test.equal(value.path, ".toss-context-fixture")
    test.equal(value.start_line, nil)
    test.equal(value.end_line, nil)
  end)

  test.it("captures the inclusive characterwise visual line range", function()
    local capture_result = capture_selection("ggvjj")

    test.equal(capture_result.kind, "ok")
    local value = assert(capture_result.value)
    test.equal(value.path, ".toss-visual-fixture")
    test.equal(value.start_line, 1)
    test.equal(value.end_line, 3)
  end)

  test.it("captures the inclusive linewise visual line range", function()
    local capture_result = capture_selection("ggVjj")

    test.equal(capture_result.kind, "ok")
    local value = assert(capture_result.value)
    test.equal(value.path, ".toss-visual-fixture")
    test.equal(value.start_line, 1)
    test.equal(value.end_line, 3)
  end)

  test.it("captures the inclusive blockwise visual line range", function()
    local capture_result = capture_selection("gg" .. string.char(22) .. "jj")

    test.equal(capture_result.kind, "ok")
    local value = assert(capture_result.value)
    test.equal(value.path, ".toss-visual-fixture")
    test.equal(value.start_line, 1)
    test.equal(value.end_line, 3)
  end)

  test.it("normalizes a reverse visual selection", function()
    local capture_result = capture_selection("3Gvkk")

    test.equal(capture_result.kind, "ok")
    local value = assert(capture_result.value)
    test.equal(value.path, ".toss-visual-fixture")
    test.equal(value.start_line, 1)
    test.equal(value.end_line, 3)
  end)

  test.it("prefers the .git ancestor over the working directory", function()
    edit(repository_path)

    local value = capture_success()

    test.equal(value.path, "nested.txt")
  end)

  test.it("uses a package marker before the working directory", function()
    edit(marker_path)

    local value = capture_success()

    test.equal(value.path, "src/marker.txt")
  end)

  test.it("uses the working directory when no configured marker exists", function()
    local original_directory = vim.fn.getcwd()
    vim.cmd("lcd " .. vim.fn.fnameescape(fallback_root))
    edit(fallback_path)

    local value = capture_success()

    vim.cmd("lcd " .. vim.fn.fnameescape(original_directory))

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

    local value = capture_success()

    test.equal(value.path, outside_path)
    test.equal(value.start_line, nil)
    test.equal(value.end_line, nil)
  end)

  test.it("uses an absolute path when no project root is resolved", function()
    edit(inside_path)

    local previous_resolve = project_root.resolve
    rawset(project_root, "resolve", function()
      return nil
    end)

    local value = capture_success()

    rawset(project_root, "resolve", previous_resolve)

    test.equal(value.path, inside_path)
  end)
end)

vim.fn.delete(inside_path)
vim.fn.delete(visual_path)
vim.fn.delete(repository_root, "rf")
vim.fn.delete(marker_root, "rf")
vim.fn.delete(fallback_root, "rf")
vim.fn.delete(outside_path)
test.finish()
