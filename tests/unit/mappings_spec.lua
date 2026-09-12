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

local function run()
  return true
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

      test.equal(setup_result.kind, "ok")
    end)

    test.equal(calls, 0)
  end)

  test.it("registers file and register mappings from one configuration", function()
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
      local setup_result = mappings.setup(true, run)

      test.equal(setup_result.kind, "ok")
    end)

    local expected = {
      { key = "<leader>th", desc = "Toss left" },
      { key = "<leader>tj", desc = "Toss down" },
      { key = "<leader>tk", desc = "Toss up" },
      { key = "<leader>tl", desc = "Toss right" },
      { key = "<leader>tyh", desc = "Toss yank left" },
      { key = "<leader>tyj", desc = "Toss yank down" },
      { key = "<leader>tyk", desc = "Toss yank up" },
      { key = "<leader>tyl", desc = "Toss yank right" },
    }

    test.equal(#calls, #expected)
    for index, expected_mapping in ipairs(expected) do
      local call = calls[index]
      test.equal(call.key, expected_mapping.key)
      test.equal(call.modes[1], "n")
      test.equal(call.modes[2], "x")
      test.truthy(type(call.callback) == "function")
      test.equal(call.options.silent, true)
      test.equal(call.options.desc, expected_mapping.desc)
    end
  end)

  test.it("supports overrides and disabled directions", function()
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

      test.equal(setup_result.kind, "ok")
    end)

    test.equal(#calls, 3)
    test.equal(calls[1], "<leader>tL")
    test.equal(calls[2], "<leader>tk")
    test.equal(calls[3], "<leader>tl")
  end)

  test.it("uses one mapping configuration for both context sources", function()
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

      test.equal(setup_result.kind, "ok")
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

  test.it("returns configuration and API errors without notifying", function()
    ---@type any
    local invalid_configuration = "enabled"
    local configuration_result = mappings.setup(invalid_configuration, run)
    test.equal(configuration_result.kind, "err")
    test.equal(errors.message(configuration_result.error), "mappings must be true or a table")

    with_vim({}, function()
      local setup_result = mappings.setup(true, run)

      test.equal(setup_result.kind, "err")
      test.equal(errors.message(setup_result.error), "keymap API is unavailable")
    end)
  end)
end)

test.finish()
