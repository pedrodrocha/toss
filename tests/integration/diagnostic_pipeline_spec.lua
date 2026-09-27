package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path
vim.opt.rtp:prepend(vim.fn.getcwd())

local test = require("tests.testlib")
local toss_result = require("toss.result")
local toss = require("toss")

local fixture_path = vim.fn.getcwd() .. "/.toss-diagnostic-pipeline-fixture"
local namespace = vim.api.nvim_create_namespace("toss-diagnostic-pipeline-test")
vim.fn.writefile({ "one", "two", "three", "four", "five" }, fixture_path)
vim.cmd("edit " .. vim.fn.fnameescape(fixture_path))
local bufnr = vim.api.nvim_get_current_buf()

local function new_transport()
  local calls = {}

  return {
    calls = calls,
    available = function()
      return true
    end,
    send = function(direction, text)
      calls[#calls + 1] = {
        operation = "send",
        direction = direction,
        text = text,
      }
      return toss_result.ok()
    end,
    focus = function(direction)
      calls[#calls + 1] = {
        operation = "focus",
        direction = direction,
      }
      return toss_result.ok()
    end,
  }
end

local function configure(transport)
  toss.config = {}
  toss.setup({ transport = transport })
end

local function set_cursor(line)
  vim.api.nvim_win_set_cursor(0, { line, 0 })
end

local function set_diagnostics(diagnostics)
  vim.diagnostic.reset(namespace, bufnr)
  vim.diagnostic.set(namespace, bufnr, diagnostics)
end

local function assert_call_count(calls, expected)
  test.equal(#calls, expected)
end

local function assert_send_and_focus(calls, direction, text)
  assert_call_count(calls, 2)
  test.equal(calls[1].operation, "send")
  test.equal(calls[1].direction, direction)
  test.equal(calls[1].text, text)
  test.equal(calls[2].operation, "focus")
  test.equal(calls[2].direction, direction)
end

local function with_notifications(callback)
  local previous_notify = vim.notify
  local notifications = {}
  rawset(vim, "notify", function(message, level)
    notifications[#notifications + 1] = { message = message, level = level }
  end)

  local ok, err = xpcall(callback, debug.traceback)
  rawset(vim, "notify", previous_notify)

  if not ok then
    error(err, 0)
  end

  return notifications
end

test.describe("diagnostic public API pipeline", function()
  test.it("sends a single diagnostic on the cursor line through the public API", function()
    local transport = new_transport()
    configure(transport)
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

    test.equal(toss.right("diagnostic"), true)

    assert_send_and_focus(
      transport.calls,
      "right",
      "@.toss-diagnostic-pipeline-fixture#L2-L2 — [error test-lsp E1] single issue"
    )
  end)

  test.it("sends multiple diagnostics on the cursor line as one formatted payload", function()
    local transport = new_transport()
    configure(transport)
    set_diagnostics({
      {
        lnum = 1,
        col = 0,
        severity = vim.diagnostic.severity.ERROR,
        source = "checker",
        code = "E1",
        message = "first line issue",
      },
      {
        lnum = 1,
        col = 6,
        severity = vim.diagnostic.severity.WARN,
        source = "checker",
        code = "W2",
        message = "second line issue",
      },
      {
        lnum = 3,
        col = 0,
        severity = vim.diagnostic.severity.INFO,
        source = "checker",
        code = "I4",
        message = "other line issue",
      },
    })
    set_cursor(2)

    test.equal(toss.right("diagnostic"), true)

    assert_send_and_focus(
      transport.calls,
      "right",
      table.concat({
        "@.toss-diagnostic-pipeline-fixture#L2-L2",
        "[error checker E1] first line issue",
        "[warning checker W2] second line issue",
      }, "\n")
    )
  end)

  test.it("falls back to file-level diagnostics when the cursor line has none", function()
    local transport = new_transport()
    configure(transport)
    set_diagnostics({
      {
        lnum = 0,
        col = 0,
        severity = vim.diagnostic.severity.ERROR,
        source = "checker",
        code = "E1",
        message = "file first issue",
      },
      {
        lnum = 3,
        end_lnum = 4,
        col = 0,
        severity = vim.diagnostic.severity.INFO,
        source = "checker",
        code = "I4",
        message = "file second issue",
      },
    })
    set_cursor(3)

    test.equal(toss.right("diagnostic"), true)

    assert_send_and_focus(
      transport.calls,
      "right",
      table.concat({
        "@.toss-diagnostic-pipeline-fixture",
        "L1-L1 [error checker E1] file first issue",
        "L4-L5 [info checker I4] file second issue",
      }, "\n")
    )
  end)

  test.it("does not send a payload and notifies when the file has no diagnostics", function()
    local transport = new_transport()
    configure(transport)
    set_diagnostics({})
    set_cursor(1)

    local notifications = with_notifications(function()
      test.equal(toss.right("diagnostic"), false)
    end)

    assert_call_count(transport.calls, 0)
    test.equal(#notifications, 1)
    test.equal(notifications[1].message, "toss: no diagnostics found in current buffer")
    test.equal(notifications[1].level, vim.log.levels.WARN)
  end)

  test.it("runs diagnostic contexts through every public direction", function()
    local transport = new_transport()
    configure(transport)
    set_diagnostics({
      { lnum = 1, col = 0, severity = vim.diagnostic.severity.HINT, message = "direction issue" },
    })
    set_cursor(2)

    test.equal(toss.left("diagnostic"), true)
    test.equal(toss.down("diagnostic"), true)
    test.equal(toss.up("diagnostic"), true)
    test.equal(toss.right("diagnostic"), true)

    local expected_directions = { "left", "down", "up", "right" }
    local expected_text = "@.toss-diagnostic-pipeline-fixture#L2-L2 — [hint] direction issue"
    assert_call_count(transport.calls, #expected_directions * 2)
    for index, direction in ipairs(expected_directions) do
      local send_call = transport.calls[(index * 2) - 1]
      local focus_call = transport.calls[index * 2]
      test.equal(send_call.operation, "send")
      test.equal(send_call.direction, direction)
      test.equal(send_call.text, expected_text)
      test.equal(focus_call.operation, "focus")
      test.equal(focus_call.direction, direction)
    end
  end)

  test.it("defaults public directional methods to the file-buffer origin", function()
    local transport = new_transport()
    configure(transport)
    set_diagnostics({})
    set_cursor(2)

    test.equal(toss.left(), true)
    test.equal(toss.down(), true)
    test.equal(toss.up(), true)
    test.equal(toss.right(), true)

    local expected_directions = { "left", "down", "up", "right" }
    assert_call_count(transport.calls, #expected_directions * 2)
    for index, direction in ipairs(expected_directions) do
      local send_call = transport.calls[(index * 2) - 1]
      local focus_call = transport.calls[index * 2]
      test.equal(send_call.operation, "send")
      test.equal(send_call.direction, direction)
      test.equal(send_call.text, "@.toss-diagnostic-pipeline-fixture")
      test.equal(focus_call.operation, "focus")
      test.equal(focus_call.direction, direction)
    end
  end)
end)

vim.diagnostic.reset(namespace, bufnr)
vim.fn.delete(fixture_path)
test.finish()
