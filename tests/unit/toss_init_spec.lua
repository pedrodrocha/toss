package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local toss = require("toss")
local context = require("toss.context")
local transports = require("toss.transports")
local herdr = transports.registry.herdr

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

local function with_vim(fake_vim, callback)
  local previous_vim = _G.vim
  _G.vim = fake_vim

  local ok, err = xpcall(callback, debug.traceback)
  _G.vim = previous_vim

  if not ok then
    error(err, 0)
  end
end

local function with_herdr_send(fake_send, callback)
  local previous_send = herdr.send
  herdr.send = fake_send

  local ok, err = xpcall(callback, debug.traceback)
  herdr.send = previous_send

  if not ok then
    error(err, 0)
  end
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

test.describe("toss transport configuration", function()
  test.it("loads Herdr when configured by name", function()
    local calls = {}
    toss.config = {}
    toss.setup({ transport = "herdr" })

    with_herdr_send(function(direction, text)
      calls[#calls + 1] = { direction = direction, text = text }
      return true
    end, function()
      with_fake_context(function()
        test.equal(toss.right(), true)
      end)
    end)

    test.equal(#calls, 1)
    test.equal(calls[1].direction, "right")
    test.equal(calls[1].text, "@src/domain/user.lua")
  end)

  test.it("fails gracefully for an unknown transport name", function()
    toss.config = {}
    toss.setup({ transport = "tmux" })

    local notifications = with_notifications(function()
      test.equal(toss.left(), false)
    end)

    test.equal(#notifications, 1)
    test.equal(notifications[1].message, "toss: unknown transport: tmux")
  end)
end)

test.describe("toss automatic transport selection", function()
  test.it("selects an available registered transport", function()
    local calls = {}
    toss.config = {}
    toss.setup({ transport = "auto" })

    with_vim({
      env = {
        HERDR_ENV = "1",
        HERDR_PANE_ID = "source-pane",
      },
    }, function()
      with_herdr_send(function(direction, text)
        calls[#calls + 1] = { direction = direction, text = text }
        return true
      end, function()
        with_fake_context(function()
          test.equal(toss.right(), true)
        end)
      end)
    end)

    test.equal(#calls, 1)
    test.equal(calls[1].direction, "right")
    test.equal(calls[1].text, "@src/domain/user.lua")
  end)

  test.it("fails gracefully when no registered transport is available", function()
    toss.config = {}
    toss.setup({ transport = "auto" })

    local notifications = with_notifications(function()
      test.equal(toss.left(), false)
    end)

    test.equal(#notifications, 1)
    test.equal(notifications[1].message, "toss: no transport is available")
  end)

  test.it("checks registered transports in deterministic order", function()
    local previous_priorities = transports.priorities
    local previous_first = transports.registry.first
    local previous_second = transports.registry.second
    local checks = {}
    local first_transport = {
      available = function()
        checks[#checks + 1] = "first"
        return false
      end,
    }
    local second_transport = {
      available = function()
        checks[#checks + 1] = "second"
        return true
      end,
    }

    transports.priorities = { "first", "second" }
    transports.registry.first = first_transport
    transports.registry.second = second_transport

    local selected, err = transports.resolve("auto")

    transports.priorities = previous_priorities
    transports.registry.first = previous_first
    transports.registry.second = previous_second

    test.equal(err, nil)
    test.equal(selected, second_transport)
    test.equal(checks[1], "first")
    test.equal(checks[2], "second")
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
