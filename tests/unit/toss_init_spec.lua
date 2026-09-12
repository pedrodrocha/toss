package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local errors = require("toss.errors")
local result = require("toss.result")
local toss = require("toss")
local context = require("toss.context")
local transports = require("toss.transports")
local herdr = transports.registry.herdr

local function with_fake_context(callback)
  local previous_capture = context.capture
  rawset(context, "capture", function()
    return result.ok({
      path = "src/domain/user.lua",
      start_line = nil,
      end_line = nil,
    })
  end)

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
    log = { levels = { WARN = "warn", ERROR = "error" } },
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

local function with_keymaps(callback)
  local previous_vim = _G.vim
  local calls = {}
  _G.vim = {
    keymap = {
      set = function(modes, key, mapping_callback, options)
        calls[#calls + 1] = {
          modes = modes,
          key = key,
          callback = mapping_callback,
          options = options,
        }
      end,
    },
  }

  local ok, err = xpcall(callback, debug.traceback)
  _G.vim = previous_vim

  if not ok then
    error(err, 0)
  end

  return calls
end

local function with_herdr_send(fake_send, callback)
  local previous_send = herdr.send
  herdr.send = function(direction, text)
    local sent = fake_send(direction, text)
    if sent == true then
      return result.ok()
    end

    return sent
  end

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

  test.it("notifies for invalid setup options", function()
    toss.config = {}

    ---@type any
    local invalid_options = "enabled"
    local notifications = with_notifications(function()
      toss.setup(invalid_options)
    end)

    test.equal(#notifications, 1)
    test.equal(notifications[1].message, "toss: setup options must be a table")
    test.equal(notifications[1].level, "error")
  end)

  test.it("does not create mappings unless enabled", function()
    toss.config = {}

    local calls = with_keymaps(function()
      toss.setup({})
    end)

    test.equal(#calls, 0)
  end)

  test.it("creates normal and visual mappings for each direction", function()
    toss.config = {}

    local calls = with_keymaps(function()
      toss.setup({ mappings = true })
    end)

    local expected = {
      { key = "<leader>th", direction = "left" },
      { key = "<leader>tj", direction = "down" },
      { key = "<leader>tk", direction = "up" },
      { key = "<leader>tl", direction = "right" },
    }

    test.equal(#calls, #expected)
    for index, mapping in ipairs(expected) do
      test.equal(calls[index].key, mapping.key)
      test.equal(calls[index].modes[1], "n")
      test.equal(calls[index].modes[2], "x")
      test.equal(calls[index].callback, toss[mapping.direction])
      test.equal(calls[index].options.silent, true)
    end
  end)

  test.it("notifies when mapping setup fails", function()
    toss.config = {}

    local notifications = with_notifications(function()
      toss.setup({ mappings = true })
    end)

    test.equal(#notifications, 1)
    test.equal(notifications[1].message, "toss: keymap API is unavailable")
    test.equal(notifications[1].level, "error")
  end)

  test.it("allows direction keys to be overridden", function()
    toss.config = {}

    local calls = with_keymaps(function()
      toss.setup({
        mappings = {
          left = "<leader>tL",
        },
      })
    end)

    test.equal(calls[1].key, "<leader>tL")
    test.equal(calls[2].key, "<leader>tj")
    test.equal(calls[3].key, "<leader>tk")
    test.equal(calls[4].key, "<leader>tl")
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
    test.equal(notifications[1].level, "error")
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
    test.equal(notifications[1].level, "warn")
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

    local selection_result = transports.resolve("auto")

    transports.priorities = previous_priorities
    transports.registry.first = previous_first
    transports.registry.second = previous_second

    test.equal(selection_result.kind, "ok")
    test.equal(selection_result.value, second_transport)
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
          return result.ok()
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

  test.it("notifies unsupported context as a warning and does not send", function()
    local send_calls = 0
    local previous_capture = context.capture
    rawset(context, "capture", function()
      return result.err(errors.buffer_not_file())
    end)

    toss.config = {
      transport = {
        send = function()
          send_calls = send_calls + 1
          return result.ok()
        end,
      },
    }

    local notifications = with_notifications(function()
      test.equal(toss.left(), false)
    end)

    rawset(context, "capture", previous_capture)

    test.equal(send_calls, 0)
    test.equal(#notifications, 1)
    test.equal(notifications[1].message, "toss: current buffer is not a file")
    test.equal(notifications[1].level, "warn")
  end)

  test.it("fails gracefully when no transport is configured", function()
    toss.config = {}

    local notifications = with_notifications(function()
      test.equal(toss.left(), false)
    end)

    test.equal(#notifications, 1)
    test.equal(notifications[1].message, "toss: transport is not configured")
    test.equal(notifications[1].level, "error")
  end)

  test.it("fails gracefully when the configured transport is invalid", function()
    toss.config = {}
    ---@type any
    local invalid_transport = {}
    toss.setup({ transport = invalid_transport })

    local notifications = with_notifications(function()
      test.equal(toss.left(), false)
    end)

    test.equal(#notifications, 1)
    test.equal(notifications[1].message, "toss: transport must provide send(direction, text)")
    test.equal(notifications[1].level, "error")
  end)
end)

test.finish()
