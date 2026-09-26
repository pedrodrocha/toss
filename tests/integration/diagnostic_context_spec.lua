package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path
vim.opt.rtp:prepend(vim.fn.getcwd())

local test = require("tests.testlib")
local errors = require("toss.errors")
local context = require("toss.context")

local fixture_path = vim.fn.getcwd() .. "/.toss-diagnostic-fixture"
local namespace = vim.api.nvim_create_namespace("toss-diagnostic-context-test")
vim.fn.writefile({ "one", "two", "three", "four", "five" }, fixture_path)
vim.cmd("edit " .. vim.fn.fnameescape(fixture_path))
local bufnr = vim.api.nvim_get_current_buf()

local function set_cursor(line)
  vim.api.nvim_win_set_cursor(0, { line, 0 })
end

local function set_diagnostics(diagnostics)
  vim.diagnostic.reset(namespace, bufnr)
  vim.diagnostic.set(namespace, bufnr, diagnostics)
end

local function messages(diagnostics)
  local result = {}
  for _, diagnostic in ipairs(diagnostics) do
    result[#result + 1] = diagnostic.message
  end
  return result
end

local function assert_messages(actual, expected)
  test.equal(#actual, #expected)
  for index, message in ipairs(expected) do
    test.equal(actual[index], message)
  end
end

local function with_diagnostic_get(diagnostics, callback)
  local original_get = vim.diagnostic.get
  rawset(vim.diagnostic, "get", function()
    return diagnostics
  end)

  local ok, value = xpcall(callback, debug.traceback)
  rawset(vim.diagnostic, "get", original_get)
  if not ok then
    error(value)
  end

  return value
end

test.describe("diagnostic context origin", function()
  test.it("captures all diagnostics on the cursor line", function()
    set_diagnostics({
      { lnum = 0, col = 0, severity = vim.diagnostic.severity.ERROR, message = "other line" },
      { lnum = 1, col = 0, severity = vim.diagnostic.severity.WARN, message = "first here" },
      { lnum = 1, col = 4, severity = vim.diagnostic.severity.ERROR, message = "second here" },
    })
    set_cursor(2)
    local expected = {}
    for _, diagnostic in ipairs(vim.diagnostic.get()) do
      if diagnostic.lnum == 1 then
        expected[#expected + 1] = diagnostic.message
      end
    end

    local captured = context.capture("diagnostic")

    test.equal(captured:is_ok(), true)
    test.equal(captured.value.kind, "diagnostic_set")
    test.equal(captured.value.items[1].path, ".toss-diagnostic-fixture")
    assert_messages(messages(captured.value.items), expected)
    test.equal(captured.value.items[1].severity, "warning")
    test.equal(captured.value.items[2].severity, "error")
  end)

  test.it("falls back to all current-buffer diagnostics when the cursor line is clear", function()
    set_diagnostics({
      { lnum = 0, col = 0, severity = vim.diagnostic.severity.ERROR, message = "first file issue" },
      { lnum = 3, col = 0, severity = vim.diagnostic.severity.INFO, message = "second file issue" },
    })
    set_cursor(2)
    local expected = messages(vim.diagnostic.get())

    local captured = context.capture("diagnostic")

    test.equal(captured:is_ok(), true)
    test.equal(captured.value.kind, "diagnostic_set")
    assert_messages(messages(captured.value.items), expected)
    test.equal(captured.value.items[1].start_line, 1)
    test.equal(captured.value.items[2].start_line, 4)
  end)

  test.it("returns one normalized diagnostic context for one selected diagnostic", function()
    set_diagnostics({
      {
        lnum = 1,
        col = 0,
        severity = vim.diagnostic.severity.ERROR,
        source = "test-lsp",
        code = "E1",
        message = "single issue",
      },
    })
    set_cursor(2)

    local captured = context.capture("diagnostic")

    test.equal(captured:is_ok(), true)
    test.equal(captured.value.kind, "diagnostic")
    test.equal(captured.value.path, ".toss-diagnostic-fixture")
    test.equal(captured.value.start_line, 2)
    test.equal(captured.value.end_line, 2)
    test.equal(captured.value.severity, "error")
    test.equal(captured.value.source, "test-lsp")
    test.equal(captured.value.code, "E1")
    test.equal(captured.value.message, "single issue")
  end)

  test.it("returns a friendly warning when the current buffer has no diagnostics", function()
    set_diagnostics({})
    set_cursor(1)

    local captured = context.capture("diagnostic")

    test.equal(captured:is_err(), true)
    test.equal(captured.value, nil)
    test.equal(errors.level(captured.error), "warn")
    test.contains(errors.message(captured.error), "no diagnostics found")
  end)

  test.it("rejects unnamed and special buffers through the file-buffer checks", function()
    vim.cmd("enew")
    local unnamed = context.capture("diagnostic")
    test.equal(unnamed:is_err(), true)
    test.contains(errors.message(unnamed.error), "no file path")

    vim.cmd("enew")
    vim.bo.buftype = "nofile"
    local special = context.capture("diagnostic")
    test.equal(special:is_err(), true)
    test.contains(errors.message(special.error), "not a file")

    vim.cmd("edit " .. vim.fn.fnameescape(fixture_path))
  end)

  test.it("normalizes reversed ranges to ascending 1-based line bounds", function()
    set_cursor(5)
    local captured = with_diagnostic_get({
      {
        lnum = 4,
        end_lnum = 2,
        severity = vim.diagnostic.severity.WARN,
        message = "reversed range",
      },
    }, function()
      return context.capture("diagnostic")
    end)

    test.equal(captured:is_ok(), true)
    test.equal(captured.value.kind, "diagnostic")
    test.equal(captured.value.start_line, 3)
    test.equal(captured.value.end_line, 5)
    test.equal(captured.value.severity, "warning")
  end)

  test.it("uses the start line when a diagnostic has no end line", function()
    set_cursor(4)
    local captured = with_diagnostic_get({
      { lnum = 3, message = "incomplete range" },
    }, function()
      return context.capture("diagnostic")
    end)

    test.equal(captured:is_ok(), true)
    test.equal(captured.value.start_line, 4)
    test.equal(captured.value.end_line, 4)
  end)

  test.it("fails the whole capture when a selected diagnostic is malformed", function()
    set_cursor(2)
    local captured = with_diagnostic_get({
      { lnum = 1, message = "valid" },
      { lnum = 1, message = false },
    }, function()
      return context.capture("diagnostic")
    end)

    test.equal(captured:is_err(), true)
    test.equal(captured.value, nil)
    test.contains(errors.message(captured.error), "invalid selected diagnostic")
  end)

  test.it("fails gracefully when a diagnostic has no usable start line", function()
    set_cursor(1)
    local captured = with_diagnostic_get({ { message = "missing line" } }, function()
      return context.capture("diagnostic")
    end)

    test.equal(captured:is_err(), true)
    test.equal(captured.value, nil)
    test.contains(errors.message(captured.error), "no valid start line")
  end)
end)

vim.diagnostic.reset(namespace, bufnr)
vim.fn.delete(fixture_path)
test.finish()
