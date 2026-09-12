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

local callbacks = {
  left = function() end,
  down = function() end,
  up = function() end,
  right = function() end,
}

local yank_callbacks = {
  left = function() end,
  down = function() end,
  up = function() end,
  right = function() end,
}

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
      local setup_result = mappings.setup(false, callbacks, yank_callbacks)

      test.equal(setup_result.kind, "ok")
    end)

    test.equal(calls, 0)
  end)

  test.it("registers default mappings for Normal and Visual mode", function()
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
      local setup_result = mappings.setup(true, callbacks, yank_callbacks)

      test.equal(setup_result.kind, "ok")
    end)

    local expected = {
      { key = "<leader>th", direction = "left", callback = callbacks.left, desc = "Toss left" },
      { key = "<leader>tj", direction = "down", callback = callbacks.down, desc = "Toss down" },
      { key = "<leader>tk", direction = "up", callback = callbacks.up, desc = "Toss up" },
      { key = "<leader>tl", direction = "right", callback = callbacks.right, desc = "Toss right" },
      { key = "<leader>tyh", direction = "left", callback = yank_callbacks.left, desc = "Toss yank left" },
      { key = "<leader>tyj", direction = "down", callback = yank_callbacks.down, desc = "Toss yank down" },
      { key = "<leader>tyk", direction = "up", callback = yank_callbacks.up, desc = "Toss yank up" },
      { key = "<leader>tyl", direction = "right", callback = yank_callbacks.right, desc = "Toss yank right" },
    }

    test.equal(#calls, #expected)
    for index, expected_mapping in ipairs(expected) do
      local call = calls[index]
      test.equal(call.key, expected_mapping.key)
      test.equal(call.modes[1], "n")
      test.equal(call.modes[2], "x")
      test.equal(call.callback, expected_mapping.callback)
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
      local setup_result = mappings.setup({ left = "<leader>tL", down = false, yank = false }, callbacks, yank_callbacks)

      test.equal(setup_result.kind, "ok")
    end)

    test.equal(#calls, 3)
    test.equal(calls[1], "<leader>tL")
    test.equal(calls[2], "<leader>tk")
    test.equal(calls[3], "<leader>tl")
  end)

  test.it("registers explicit yank mappings independently", function()
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
      local setup_result = mappings.setup({ yank = true }, callbacks, yank_callbacks)

      test.equal(setup_result.kind, "ok")
    end)

    local expected = {
      "<leader>th",
      "<leader>tj",
      "<leader>tk",
      "<leader>tl",
      "<leader>tyh",
      "<leader>tyj",
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
    local configuration_result = mappings.setup(invalid_configuration, callbacks, yank_callbacks)
    test.equal(configuration_result.kind, "err")
    test.equal(errors.message(configuration_result.error), "mappings must be true or a table")

    with_vim({}, function()
      local setup_result = mappings.setup(true, callbacks, yank_callbacks)

      test.equal(setup_result.kind, "err")
      test.equal(errors.message(setup_result.error), "keymap API is unavailable")
    end)
  end)
end)

test.finish()
