package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local errors = require("toss.errors")
local mappings = require("toss.mappings")
local mapping_config = require("toss.mappings.config")

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
local function run(direction, origin)
  run_calls[#run_calls + 1] = { direction = direction, origin = origin }
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

test.describe("mapping configuration", function()
  test.it("resolves the default surface without Neovim APIs", function()
    local resolved = mapping_config.resolve(true)
    local expected = {
      { name = "left", key = "<leader>th", direction = "left", origin = "file_buffer", description = "Toss left" },
      { name = "down", key = "<leader>tj", direction = "down", origin = "file_buffer", description = "Toss down" },
      { name = "up", key = "<leader>tk", direction = "up", origin = "file_buffer", description = "Toss up" },
      { name = "right", key = "<leader>tl", direction = "right", origin = "file_buffer", description = "Toss right" },
      { name = "yank_left", key = "<leader>tyh", direction = "left", origin = "yank", description = "Toss yank left" },
      { name = "yank_down", key = "<leader>tyj", direction = "down", origin = "yank", description = "Toss yank down" },
      { name = "yank_up", key = "<leader>tyk", direction = "up", origin = "yank", description = "Toss yank up" },
      {
        name = "yank_right",
        key = "<leader>tyl",
        direction = "right",
        origin = "yank",
        description = "Toss yank right",
      },
    }

    test.equal(resolved:is_ok(), true)
    test.equal(#resolved.value, #expected)
    for index, expected_specification in ipairs(expected) do
      for field, value in pairs(expected_specification) do
        test.equal(resolved.value[index][field], value)
      end
    end
  end)

  test.it("applies overrides and disables mappings", function()
    local resolved = mapping_config.resolve({
      left = "<leader>tL",
      down = false,
      yank_left = false,
    })

    test.equal(resolved:is_ok(), true)
    test.equal(#resolved.value, 6)
    test.equal(resolved.value[1].name, "left")
    test.equal(resolved.value[1].key, "<leader>tL")
    test.equal(resolved.value[2].name, "up")
    test.equal(resolved.value[6].name, "yank_right")
  end)

  test.it("returns errors for invalid configuration and mapping values", function()
    ---@type any
    local invalid_configuration = "enabled"
    local configuration_result = mapping_config.resolve(invalid_configuration)
    test.equal(configuration_result:is_err(), true)
    test.equal(errors.message(configuration_result.error), "mappings must be true or a table")

    ---@type any
    local invalid_mapping = { left = 42 }
    local mapping_result = mapping_config.resolve(invalid_mapping)
    test.equal(mapping_result:is_err(), true)
    test.contains(errors.message(mapping_result.error), "mapping for left")
  end)
end)

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
      { key = "<leader>th", direction = "left", origin = "file_buffer", desc = "Toss left" },
      { key = "<leader>tj", direction = "down", origin = "file_buffer", desc = "Toss down" },
      { key = "<leader>tk", direction = "up", origin = "file_buffer", desc = "Toss up" },
      { key = "<leader>tl", direction = "right", origin = "file_buffer", desc = "Toss right" },
      { key = "<leader>tyh", direction = "left", origin = "yank", desc = "Toss yank left" },
      { key = "<leader>tyj", direction = "down", origin = "yank", desc = "Toss yank down" },
      { key = "<leader>tyk", direction = "up", origin = "yank", desc = "Toss yank up" },
      { key = "<leader>tyl", direction = "right", origin = "yank", desc = "Toss yank right" },
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
      test.equal(run_calls[index].origin, expected_mapping.origin)
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

  test.it("uses one mapping configuration for both context origins", function()
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
