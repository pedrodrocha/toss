package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local context = require("toss.context")
local formatter = require("toss.formatter")
local runner = require("toss.runner")

local function with_stubs(stubs, callback)
  local previous_capture = context.capture
  local previous_format = formatter.format

  if stubs.capture then
    context.capture = stubs.capture
  end
  if stubs.format then
    formatter.format = stubs.format
  end

  local ok, err = xpcall(callback, debug.traceback)
  context.capture = previous_capture
  formatter.format = previous_format

  if not ok then
    error(err, 0)
  end
end

test.describe("toss runner", function()
  test.it("runs capture, formatting, and transport in order", function()
    local calls = {}
    local context_value = { path = "src/file.lua" }
    local transport = {
      send = function(direction, text)
        calls[#calls + 1] = { step = "send", direction = direction, text = text }
        return true
      end,
    }

    with_stubs({
      capture = function()
        calls[#calls + 1] = { step = "capture" }
        return context_value
      end,
      format = function(value)
        calls[#calls + 1] = { step = "format", context = value }
        return "@src/file.lua"
      end,
    }, function()
      local ok, err = runner.run("right", { transport = transport })

      test.equal(ok, true)
      test.equal(err, nil)
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
        return true
      end,
    }

    with_stubs({
      capture = function()
        return nil, "current buffer is not a file"
      end,
      format = function()
        format_calls = format_calls + 1
        return "should not be sent"
      end,
    }, function()
      local ok, err = runner.run("left", { transport = transport })

      test.equal(ok, false)
      test.equal(err, "current buffer is not a file")
    end)

    test.equal(format_calls, 0)
    test.equal(send_calls, 0)
  end)

  test.it("returns formatter and transport failures", function()
    local formatter_error = "invalid context"
    local transport_error = "no adjacent pane"
    local send_calls = 0

    with_stubs({
      capture = function()
        return { path = "src/file.lua" }
      end,
      format = function()
        return nil, formatter_error
      end,
    }, function()
      local ok, err = runner.run("up", {
        transport = {
          send = function()
            send_calls = send_calls + 1
            return false, transport_error
          end,
        },
      })

      test.equal(ok, false)
      test.equal(err, formatter_error)
    end)

    test.equal(send_calls, 0)

    with_stubs({
      capture = function()
        return { path = "src/file.lua" }
      end,
      format = function()
        return "@src/file.lua"
      end,
    }, function()
      local ok, err = runner.run("up", {
        transport = {
          send = function()
            return false, transport_error
          end,
        },
      })

      test.equal(ok, false)
      test.equal(err, transport_error)
    end)
  end)

  test.it("resolves and validates configured transports", function()
    local transport = { send = function() end }

    local resolved, err = runner.resolve_transport({ transport = transport })
    test.equal(resolved, transport)
    test.equal(err, nil)

    resolved, err = runner.resolve_transport({})
    test.equal(resolved, nil)
    test.equal(err, "transport is not configured")

    ---@type any
    local invalid_transport = {}
    resolved, err = runner.resolve_transport({ transport = invalid_transport })
    test.equal(resolved, nil)
    test.equal(err, "transport must provide send(direction, text)")
  end)
end)

test.finish()
