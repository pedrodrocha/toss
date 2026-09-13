package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local errors = require("toss.errors")
local mappings = require("toss.mappings")

local function with_vim(fake_vim, callback)
  local previous_vim = _G.vim
  _G.vim = fake_vim

  local ok, err = xpcall(callback, debug.traceback)
  _G.vim = previous_vim

  if not ok then
    error(err, 0)
  end
end

local run_calls = {}
local function run(direction, mode)
  run_calls[#run_calls + 1] = { direction = direction, mode = mode }
  return true
end

local function reset_mappings()
  with_vim({
    keymap = {
      set = function() end,
      del = function() end,
    },
  }, function()
    local setup_result = mappings.setup(false, run)
    test.equal(setup_result:is_ok(), true)
  end)
end

local function only_left(key)
  return {
    left = key,
    down = false,
    up = false,
    right = false,
    yank_left = false,
    yank_down = false,
    yank_up = false,
    yank_right = false,
  }
end

test.describe("toss mappings", function()
  test.it("does not register disabled mappings", function()
    local calls = 0

    with_vim({
      keymap = {
        set = function()
          calls = calls + 1
        end,
      },
    }, function()
      local setup_result = mappings.setup(false, run)

      test.equal(setup_result:is_ok(), true)
    end)

    test.equal(calls, 0)
  end)

  test.it("registers file and yank mappings from one configuration", function()
    local calls = {}
    run_calls = {}

    with_vim({
      keymap = {
        set = function(modes, key, callback, options)
          calls[#calls + 1] = {
            modes = modes,
            key = key,
            callback = callback,
            options = options,
          }
        end,
      },
    }, function()
      local setup_result = mappings.setup(true, run)

      test.equal(setup_result:is_ok(), true)
    end)

    local expected = {
      { key = "<leader>th", direction = "left", mode = "file", desc = "Toss left" },
      { key = "<leader>tj", direction = "down", mode = "file", desc = "Toss down" },
      { key = "<leader>tk", direction = "up", mode = "file", desc = "Toss up" },
      { key = "<leader>tl", direction = "right", mode = "file", desc = "Toss right" },
      { key = "<leader>tyh", direction = "left", mode = "yank", desc = "Toss yank left" },
      { key = "<leader>tyj", direction = "down", mode = "yank", desc = "Toss yank down" },
      { key = "<leader>tyk", direction = "up", mode = "yank", desc = "Toss yank up" },
      { key = "<leader>tyl", direction = "right", mode = "yank", desc = "Toss yank right" },
    }

    test.equal(#calls, #expected)
    for index, expected_mapping in ipairs(expected) do
      local call = calls[index]
      test.equal(call.key, expected_mapping.key)
      test.equal(call.modes[1], "n")
      test.equal(call.modes[2], "x")
      test.truthy(type(call.callback) == "function")
      call.callback()
      test.equal(run_calls[index].direction, expected_mapping.direction)
      test.equal(run_calls[index].mode, expected_mapping.mode)
      test.equal(call.options.silent, true)
      test.equal(call.options.desc, expected_mapping.desc)
    end
  end)

  test.it("supports overrides and disabled directions", function()
    reset_mappings()
    local calls = {}

    with_vim({
      keymap = {
        set = function(_, key)
          calls[#calls + 1] = key
        end,
      },
    }, function()
      local setup_result = mappings.setup({
        left = "<leader>tL",
        down = false,
        yank_left = false,
        yank_down = false,
        yank_up = false,
        yank_right = false,
      }, run)

      test.equal(setup_result:is_ok(), true)
    end)

    test.equal(#calls, 3)
    test.equal(calls[1], "<leader>tL")
    test.equal(calls[2], "<leader>tk")
    test.equal(calls[3], "<leader>tl")
  end)

  test.it("uses one mapping configuration for both context modes", function()
    reset_mappings()
    local calls = {}

    with_vim({
      keymap = {
        set = function(modes, key, callback, options)
          calls[#calls + 1] = {
            modes = modes,
            key = key,
            callback = callback,
            options = options,
          }
        end,
      },
    }, function()
      local setup_result = mappings.setup({ yank_left = "<leader>tyH", yank_down = false }, run)

      test.equal(setup_result:is_ok(), true)
    end)

    local expected = {
      "<leader>th",
      "<leader>tj",
      "<leader>tk",
      "<leader>tl",
      "<leader>tyH",
      "<leader>tyk",
      "<leader>tyl",
    }

    test.equal(#calls, #expected)
    for index, key in ipairs(expected) do
      test.equal(calls[index].key, key)
    end
  end)

  test.it("removes old mappings before installing a reconfigured set", function()
    reset_mappings()
    local registered = {}
    local removed = {}

    with_vim({
      keymap = {
        set = function(_, key)
          registered[#registered + 1] = key
        end,
        del = function(mode, key)
          removed[#removed + 1] = { mode = mode, key = key }
        end,
      },
    }, function()
      test.equal(mappings.setup(only_left("<leader>told"), run):is_ok(), true)
      test.equal(mappings.setup(only_left("<leader>tnew"), run):is_ok(), true)
    end)

    test.equal(#registered, 2)
    test.equal(registered[1], "<leader>told")
    test.equal(registered[2], "<leader>tnew")
    test.equal(#removed, 2)
    test.equal(removed[1].mode, "n")
    test.equal(removed[1].key, "<leader>told")
    test.equal(removed[2].mode, "x")
    test.equal(removed[2].key, "<leader>told")
  end)

  test.it("removes all owned mappings when disabled", function()
    reset_mappings()
    local removed = {}

    with_vim({
      keymap = {
        set = function() end,
        del = function(mode, key)
          removed[#removed + 1] = { mode = mode, key = key }
        end,
      },
    }, function()
      test.equal(mappings.setup(true, run):is_ok(), true)
      test.equal(mappings.setup(false, run):is_ok(), true)
    end)

    test.equal(#removed, 16)
  end)

  test.it("does not repeat an identical setup", function()
    reset_mappings()
    local registered = 0
    local removed = 0

    with_vim({
      keymap = {
        set = function()
          registered = registered + 1
        end,
        del = function()
          removed = removed + 1
        end,
      },
    }, function()
      test.equal(mappings.setup(only_left("<leader>tleft"), run):is_ok(), true)
      test.equal(mappings.setup(only_left("<leader>tleft"), run):is_ok(), true)
    end)

    test.equal(registered, 1)
    test.equal(removed, 0)
  end)

  test.it("validates configuration before removing active mappings", function()
    reset_mappings()
    local registered = 0
    local removed = 0

    with_vim({
      keymap = {
        set = function()
          registered = registered + 1
        end,
        del = function()
          removed = removed + 1
        end,
      },
    }, function()
      test.equal(mappings.setup(only_left("<leader>tactive"), run):is_ok(), true)
      ---@type any
      local invalid_mappings = { left = 42 }
      local setup_result = mappings.setup(invalid_mappings, run)

      test.equal(setup_result:is_err(), true)
      test.equal(registered, 1)
      test.equal(removed, 0)
    end)
  end)

  test.it("reports mapping removal failures before installing the new setup", function()
    reset_mappings()
    local should_fail = false
    local registered = 0

    with_vim({
      keymap = {
        set = function()
          registered = registered + 1
        end,
        del = function(mode)
          if should_fail and mode == "n" then
            error("delete exploded")
          end
        end,
      },
    }, function()
      test.equal(mappings.setup(only_left("<leader>told"), run):is_ok(), true)
      should_fail = true
      local setup_result = mappings.setup(only_left("<leader>tnew"), run)

      test.equal(setup_result:is_err(), true)
      test.contains(errors.message(setup_result.error), "could not remove left mapping")
      test.equal(registered, 1)
    end)
  end)

  test.it("reports mapping installation failures", function()
    reset_mappings()
    local should_fail = false
    local removed = 0

    with_vim({
      keymap = {
        set = function(_, key)
          if should_fail and key == "<leader>tnew" then
            error("set exploded")
          end
        end,
        del = function()
          removed = removed + 1
        end,
      },
    }, function()
      test.equal(mappings.setup(only_left("<leader>told"), run):is_ok(), true)
      should_fail = true
      local setup_result = mappings.setup(only_left("<leader>tnew"), run)

      test.equal(setup_result:is_err(), true)
      test.contains(errors.message(setup_result.error), "could not register left mapping")
      test.equal(removed, 2)
    end)
  end)

  test.it("returns configuration and API errors without notifying", function()
    reset_mappings()
    ---@type any
    local invalid_configuration = "enabled"
    local configuration_result = mappings.setup(invalid_configuration, run)
    test.equal(configuration_result:is_err(), true)
    test.equal(errors.message(configuration_result.error), "mappings must be true or a table")

    with_vim({}, function()
      local setup_result = mappings.setup(true, run)

      test.equal(setup_result:is_err(), true)
      test.equal(errors.message(setup_result.error), "keymap API is unavailable")
    end)
  end)
end)

test.finish()
