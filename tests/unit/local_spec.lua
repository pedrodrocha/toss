package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local local_transport = require("toss.transports.local")
local transports = require("toss.transports")

local function with_vim(fake_vim, callback)
  local previous_vim = _G.vim
  _G.vim = fake_vim

  local ok, err = xpcall(callback, debug.traceback)
  _G.vim = previous_vim

  if not ok then
    error(err, 0)
  end
end

test.describe("local transport", function()
  test.it("is available without inspecting the external environment", function()
    local process_calls = 0

    with_vim({
      env = {},
      system = function()
        process_calls = process_calls + 1
      end,
    }, function()
      test.equal(local_transport.available(), true)
    end)

    test.equal(process_calls, 0)
  end)

  test.it("records send and focus calls on its singleton", function()
    local_transport.reset()

    with_vim({}, function()
      test.equal(local_transport.send("right", "@src/file.lua#L2-L4"):is_ok(), true)
      test.equal(local_transport.focus("right"):is_ok(), true)
    end)

    local calls = local_transport.calls()
    test.equal(#calls, 2)
    test.equal(calls[1].operation, "send")
    test.equal(calls[1].direction, "right")
    test.equal(calls[1].text, "@src/file.lua#L2-L4")
    test.equal(calls[2].operation, "focus")
    test.equal(calls[2].direction, "right")
    test.equal(calls[2].text, nil)
  end)

  test.it("reports the exact send through an info notification", function()
    local notifications = {}
    local_transport.reset()

    with_vim({
      log = { levels = { INFO = "info" } },
      notify = function(message, level)
        notifications[#notifications + 1] = { message = message, level = level }
      end,
    }, function()
      test.equal(local_transport.send("left", "@README.md; printf hacked"):is_ok(), true)
      test.equal(local_transport.focus("left"):is_ok(), true)
    end)

    test.equal(#notifications, 1)
    test.equal(notifications[1].message, "toss: local transport would send left: @README.md; printf hacked")
    test.equal(notifications[1].level, "info")
  end)

  test.it("falls back to an info message and performs no pane operations", function()
    local messages = 0
    local process_calls = 0
    local key_calls = 0
    local_transport.reset()

    with_vim({
      api = {
        nvim_echo = function()
          messages = messages + 1
        end,
        nvim_input = function()
          key_calls = key_calls + 1
        end,
      },
      system = function()
        process_calls = process_calls + 1
      end,
    }, function()
      test.equal(local_transport.send("up", "@src/file.lua"):is_ok(), true)
      test.equal(local_transport.focus("up"):is_ok(), true)
    end)

    test.equal(messages, 1)
    test.equal(process_calls, 0)
    test.equal(key_calls, 0)
  end)

  test.it("resets recorded calls", function()
    local_transport.reset()

    with_vim({}, function()
      local_transport.send("down", "@src/file.lua")
    end)

    test.equal(#local_transport.calls(), 1)
    local_transport.reset()
    test.equal(#local_transport.calls(), 0)
  end)
end)

test.describe("local transport registration", function()
  test.it("resolves when explicitly selected", function()
    local resolved = transports.resolve("local")

    test.equal(resolved:is_ok(), true)
    test.equal(resolved.value, transports.registry["local"])
  end)

  test.it("is excluded from automatic selection", function()
    local previous_vim = _G.vim
    _G.vim = { env = {} }

    local resolved = transports.resolve("auto")

    _G.vim = previous_vim

    test.equal(resolved:is_err(), true)
    test.equal(resolved.error.code, "no_transport_available")
  end)
end)

test.finish()
