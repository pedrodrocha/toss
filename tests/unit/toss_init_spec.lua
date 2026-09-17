package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local errors = require("toss.errors")
local result = require("toss.result")
local toss = require("toss")
local context = require("toss.context")
local transports = require("toss.transports")
local local_transport = require("toss.transports.local")
local herdr = transports.registry.herdr

-- Unit tests provide only the Neovim APIs used by toss.setup().
_G.vim = {
  api = {
    nvim_create_augroup = function()
      return 1
    end,
    nvim_create_autocmd = function()
      return 1
    end,
  },
}

local function with_fake_context(callback)
  local previous_capture = context.capture
  local captured_origin
  rawset(context, "capture", function(origin)
    captured_origin = origin
    return result.ok({
      kind = "file",
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

  return captured_origin
end

local function with_notifications(callback)
  local previous_vim = _G.vim
  local notifications = {}
  _G.vim = {
    api = {
      nvim_create_augroup = function()
        return 1
      end,
      nvim_create_autocmd = function()
        return 1
      end,
    },
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
    api = {
      nvim_create_augroup = function()
        return 1
      end,
      nvim_create_autocmd = function()
        return 1
      end,
    },
    keymap = {
      set = function(modes, key, mapping_callback, options)
        calls[#calls + 1] = {
          modes = modes,
          key = key,
          callback = mapping_callback,
          options = options,
        }
      end,
      del = function() end,
    },
  }

  local ok, err = xpcall(callback, debug.traceback)
  _G.vim = previous_vim

  if not ok then
    error(err, 0)
  end

  return calls
end

local function clear_mappings()
  with_keymaps(function()
    toss.setup({ mappings = false })
  end)
end

local function with_herdr_send(fake_send, callback)
  local previous_send = herdr.send
  local previous_focus = herdr.focus
  herdr.send = function(direction, text)
    local sent = fake_send(direction, text)
    if sent == true then
      return result.ok()
    end

    return sent
  end
  herdr.focus = function()
    return result.ok()
  end

  local ok, err = xpcall(callback, debug.traceback)
  herdr.send = previous_send
  herdr.focus = previous_focus

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

  test.it("creates file and explicit yank mappings when enabled", function()
    toss.config = {}

    local calls = with_keymaps(function()
      toss.setup({ mappings = true })
    end)

    local expected = {
      { key = "<leader>th", direction = "left", desc = "Toss left" },
      { key = "<leader>tj", direction = "down", desc = "Toss down" },
      { key = "<leader>tk", direction = "up", desc = "Toss up" },
      { key = "<leader>tl", direction = "right", desc = "Toss right" },
      { key = "<leader>tyh", desc = "Toss yank left" },
      { key = "<leader>tyj", desc = "Toss yank down" },
      { key = "<leader>tyk", desc = "Toss yank up" },
      { key = "<leader>tyl", desc = "Toss yank right" },
    }

    test.equal(#calls, #expected)
    for index, mapping in ipairs(expected) do
      test.equal(calls[index].key, mapping.key)
      test.equal(calls[index].modes[1], "n")
      test.equal(calls[index].modes[2], "x")
      test.equal(calls[index].options.silent, true)
      test.equal(calls[index].options.desc, mapping.desc)
      test.truthy(type(calls[index].callback) == "function")
    end
  end)

  test.it("notifies when mapping setup fails", function()
    clear_mappings()
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
      local captured_origin = with_fake_context(function()
        test.equal(toss.right(), true)
      end)
      test.equal(captured_origin, "file_buffer")
    end)

    test.equal(#calls, 1)
    test.equal(calls[1].direction, "right")
    test.equal(calls[1].text, "@src/domain/user.lua")
  end)

  test.it("loads the local transport when configured by name", function()
    local transport = local_transport
    transport.reset()
    toss.config = {}
    toss.setup({ transport = "local" })

    with_fake_context(function()
      test.equal(toss.right(), true)
    end)

    local calls = transport.calls()
    test.equal(#calls, 2)
    test.equal(calls[1].operation, "send")
    test.equal(calls[1].direction, "right")
    test.equal(calls[1].text, "@src/domain/user.lua")
    test.equal(calls[2].operation, "focus")
    test.equal(calls[2].direction, "right")
    transport.reset()
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

    test.equal(selection_result:is_ok(), true)
    test.equal(selection_result.value, second_transport)
    test.equal(checks[1], "first")
    test.equal(checks[2], "second")
  end)
end)

test.describe("toss directions", function()
  test.it("sends the formatted context and each direction to the local transport", function()
    local transport = local_transport
    transport.reset()
    toss.config = {}
    toss.setup({ transport = transport })

    with_fake_context(function()
      test.equal(toss.left(), true)
      test.equal(toss.down(), true)
      test.equal(toss.up(), true)
      test.equal(toss.right(), true)
    end)

    local calls = transport.calls()
    local expected_directions = { "left", "down", "up", "right" }
    test.equal(#calls, #expected_directions * 2)
    for index, direction in ipairs(expected_directions) do
      local send_call = calls[(index * 2) - 1]
      local focus_call = calls[index * 2]
      test.equal(send_call.operation, "send")
      test.equal(send_call.direction, direction)
      test.equal(send_call.text, "@src/domain/user.lua")
      test.equal(focus_call.operation, "focus")
      test.equal(focus_call.direction, direction)
    end
  end)

  test.it("passes an explicit yank origin through the public API", function()
    local_transport.reset()
    toss.setup({ transport = local_transport })

    local captured_origin = with_fake_context(function()
      test.equal(toss.left("yank"), true)
    end)

    test.equal(captured_origin, "yank")
  end)

  test.it("notifies unsupported context as a warning and does not send", function()
    local send_calls = 0
    local previous_capture = context.capture
    rawset(context, "capture", function()
      return result.err(errors.buffer_not_file())
    end)

    toss.setup({
      transport = {
        send = function()
          send_calls = send_calls + 1
          return result.ok()
        end,
        focus = function()
          error("focus should not run")
        end,
        available = function()
          return true
        end,
      },
    })

    local notifications = with_notifications(function()
      test.equal(toss.left(), false)
    end)

    rawset(context, "capture", previous_capture)

    test.equal(send_calls, 0)
    test.equal(#notifications, 1)
    test.equal(notifications[1].message, "toss: current buffer is not a file")
    test.equal(notifications[1].level, "warn")
  end)

  test.it("notifies focus failures through the toss error path", function()
    toss.setup({
      transport = {
        send = function()
          return result.ok()
        end,
        focus = function()
          return result.err(errors.transport_focus("destination unavailable"))
        end,
        available = function()
          return true
        end,
      },
    })

    local notifications = with_notifications(function()
      with_fake_context(function()
        test.equal(toss.right(), false)
      end)
    end)

    test.equal(#notifications, 1)
    test.equal(notifications[1].message, "toss: transport focus failed: destination unavailable")
    test.equal(notifications[1].level, "error")
  end)

  test.it("fails gracefully when no transport is configured", function()
    toss.config = {}
    toss.setup({})

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
    test.equal(
      notifications[1].message,
      "toss: transport must provide send(direction, text), focus(direction), and available()"
    )
    test.equal(notifications[1].level, "error")
  end)
end)

test.finish()
