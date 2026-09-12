package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local errors = require("toss.errors")
local result = require("toss.result")
local context = require("toss.context")
local formatter = require("toss.formatter")
local runner = require("toss.runner")

local function with_stubs(stubs, callback)
  local previous_capture = context.capture
  local previous_format = formatter.format

  if stubs.capture then
    rawset(context, "capture", stubs.capture)
  end
  if stubs.format then
    rawset(formatter, "format", stubs.format)
  end

  local ok, err = xpcall(callback, debug.traceback)
  rawset(context, "capture", previous_capture)
  rawset(formatter, "format", previous_format)

  if not ok then
    error(err, 0)
  end
end

local function assert_failure(outcome)
  test.equal(outcome.kind, "err")
  return outcome.error
end

test.describe("toss runner", function()
  test.it("passes the requested context mode through capture", function()
    local captured_mode

    with_stubs({
      capture = function(mode)
        captured_mode = mode
        return result.ok({ path = "src/file.lua" })
      end,
      format = function()
        return result.ok("@src/file.lua")
      end,
    }, function()
      local run_result = runner.run("right", "yank", {
        transport = {
          send = function()
            return result.ok()
          end,
        },
      })

      test.equal(run_result.kind, "ok")
    end)

    test.equal(captured_mode, "yank")
  end)

  test.it("runs capture, formatting, and transport in order", function()
    local calls = {}
    local context_value = { path = "src/file.lua" }
    local transport = {
      send = function(direction, text)
        calls[#calls + 1] = { step = "send", direction = direction, text = text }
        return result.ok()
      end,
    }

    with_stubs({
      capture = function()
        calls[#calls + 1] = { step = "capture" }
        return result.ok(context_value)
      end,
      format = function(value)
        calls[#calls + 1] = { step = "format", context = value }
        return result.ok("@src/file.lua")
      end,
    }, function()
      local run_result = runner.run("right", nil, { transport = transport })

      test.equal(run_result.kind, "ok")
    end)

    test.equal(calls[1].step, "capture")
    test.equal(calls[2].step, "format")
    test.equal(calls[2].context, context_value)
    test.equal(calls[3].step, "send")
    test.equal(calls[3].direction, "right")
    test.equal(calls[3].text, "@src/file.lua")
  end)

  test.it("returns capture failures without continuing the pipeline", function()
    local format_calls = 0
    local send_calls = 0
    local transport = {
      send = function()
        send_calls = send_calls + 1
        return result.ok()
      end,
    }

    with_stubs({
      capture = function()
        return result.err(errors.buffer_not_file())
      end,
      format = function()
        format_calls = format_calls + 1
        return result.ok("should not be sent")
      end,
    }, function()
      local run_result = runner.run("left", nil, { transport = transport })

      test.equal(errors.message(assert_failure(run_result)), "current buffer is not a file")
    end)

    test.equal(format_calls, 0)
    test.equal(send_calls, 0)
  end)

  test.it("returns formatter and transport failures", function()
    local formatter_error = errors.invalid_context()
    local transport_error = errors.herdr_neighbor("up")
    local send_calls = 0

    with_stubs({
      capture = function()
        return result.ok({ path = "src/file.lua" })
      end,
      format = function()
        return result.err(formatter_error)
      end,
    }, function()
      local run_result = runner.run("up", nil, {
        transport = {
          send = function()
            send_calls = send_calls + 1
            return result.err(transport_error)
          end,
        },
      })

      test.equal(errors.message(assert_failure(run_result)), errors.message(formatter_error))
    end)

    test.equal(send_calls, 0)

    with_stubs({
      capture = function()
        return result.ok({ path = "src/file.lua" })
      end,
      format = function()
        return result.ok("@src/file.lua")
      end,
    }, function()
      local run_result = runner.run("up", nil, {
        transport = {
          send = function()
            return result.err(transport_error)
          end,
        },
      })

      test.equal(errors.message(assert_failure(run_result)), errors.message(transport_error))
    end)
  end)

  test.it("rejects invalid transport results without reporting success", function()
    local send_calls = 0

    with_stubs({
      capture = function()
        return result.ok({ path = "src/file.lua" })
      end,
      format = function()
        return result.ok("@src/file.lua")
      end,
    }, function()
      local run_result = runner.run("right", nil, {
        transport = {
          send = function()
            send_calls = send_calls + 1
            ---@type any
            local invalid_result = nil
            return invalid_result
          end,
        },
      })

      test.equal(errors.message(assert_failure(run_result)), "transport must return a Result")
    end)

    test.equal(send_calls, 1)
  end)

  test.it("converts transport exceptions into failures", function()
    with_stubs({
      capture = function()
        return result.ok({ path = "src/file.lua" })
      end,
      format = function()
        return result.ok("@src/file.lua")
      end,
    }, function()
      local run_result = runner.run("right", nil, {
        transport = {
          send = function()
            error("send exploded")
          end,
        },
      })

      local err = assert_failure(run_result)
      test.contains(errors.message(err), "transport failed: ")
      test.contains(errors.message(err), "send exploded")
    end)
  end)

  test.it("returns transport configuration failures without capturing context", function()
    local capture_calls = 0

    with_stubs({
      capture = function()
        capture_calls = capture_calls + 1
        return result.ok({ path = "src/file.lua" })
      end,
    }, function()
      local run_result = runner.run("right", nil, {})

      test.equal(errors.message(assert_failure(run_result)), "transport is not configured")
    end)

    test.equal(capture_calls, 0)
  end)
end)

test.finish()
