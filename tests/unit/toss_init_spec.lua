package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local toss = require("toss")
local context = require("toss.context")

local function with_fake_context(callback)
  local previous_capture = context.capture
  context.capture = function()
    return {
      path = "src/domain/user.lua",
      start_line = nil,
      end_line = nil,
    }
  end

  local ok, err = xpcall(callback, debug.traceback)
  context.capture = previous_capture

  if not ok then
    error(err, 0)
  end
end

local function with_notifications(callback)
  local previous_vim = _G.vim
  local notifications = {}
  _G.vim = {
    log = { levels = { INFO = "info" } },
    notify = function(message, level)
      notifications[#notifications + 1] = { message = message, level = level }
    end,
  }

  local ok, err = xpcall(callback, debug.traceback)
  _G.vim = previous_vim

  if not ok then
    error(err, 0)
  end

  return notifications
end

test.describe("toss setup", function()
  test.it("merges configuration and returns the module", function()
    toss.config = {}

    test.equal(toss.setup({ first = true }), toss)
    toss.setup({ second = "value" })

    test.equal(toss.config.first, true)
    test.equal(toss.config.second, "value")
  end)
end)

test.describe("toss directions", function()
  test.it("sends the formatted context and each direction to the transport", function()
    local calls = {}
    toss.config = {}
    toss.setup({
      transport = {
        send = function(direction, text)
          calls[#calls + 1] = { direction = direction, text = text }
          return true
        end,
      },
    })

    with_fake_context(function()
      test.equal(toss.left(), true)
      test.equal(toss.down(), true)
      test.equal(toss.up(), true)
      test.equal(toss.right(), true)
    end)

    local expected_directions = { "left", "down", "up", "right" }
    test.equal(#calls, #expected_directions)
    for index, direction in ipairs(expected_directions) do
      test.equal(calls[index].direction, direction)
      test.equal(calls[index].text, "@src/domain/user.lua")
    end
  end)

  test.it("fails gracefully when no transport is configured", function()
    toss.config = {}

    local notifications = with_notifications(function()
      test.equal(toss.left(), false)
    end)

    test.equal(#notifications, 1)
    test.equal(notifications[1].message, "toss: transport is not configured")
  end)

  test.it("fails gracefully when the configured transport is invalid", function()
    toss.config = {}
    toss.setup({ transport = {} })

    local notifications = with_notifications(function()
      test.equal(toss.left(), false)
    end)

    test.equal(#notifications, 1)
    test.equal(notifications[1].message, "toss: transport must provide send(direction, text)")
  end)
end)

test.finish()
