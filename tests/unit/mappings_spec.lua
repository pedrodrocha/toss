package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
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
      local ok, err = mappings.setup(false, callbacks)

      test.equal(ok, true)
      test.equal(err, nil)
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
      local ok, err = mappings.setup(true, callbacks)

      test.equal(ok, true)
      test.equal(err, nil)
    end)

    local expected = {
      { key = "<leader>th", direction = "left" },
      { key = "<leader>tj", direction = "down" },
      { key = "<leader>tk", direction = "up" },
      { key = "<leader>tl", direction = "right" },
    }

    test.equal(#calls, #expected)
    for index, expected_mapping in ipairs(expected) do
      local call = calls[index]
      test.equal(call.key, expected_mapping.key)
      test.equal(call.modes[1], "n")
      test.equal(call.modes[2], "x")
      test.equal(call.callback, callbacks[expected_mapping.direction])
      test.equal(call.options.silent, true)
      test.equal(call.options.desc, "Toss " .. expected_mapping.direction)
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
      local ok, err = mappings.setup({ left = "<leader>tL", down = false }, callbacks)

      test.equal(ok, true)
      test.equal(err, nil)
    end)

    test.equal(#calls, 3)
    test.equal(calls[1], "<leader>tL")
    test.equal(calls[2], "<leader>tk")
    test.equal(calls[3], "<leader>tl")
  end)

  test.it("returns configuration and API errors without notifying", function()
    local ok, err = mappings.setup("enabled", callbacks)
    test.equal(ok, false)
    test.equal(err, "mappings must be true or a table")

    with_vim({}, function()
      ok, err = mappings.setup(true, callbacks)

      test.equal(ok, false)
      test.equal(err, "keymap API is unavailable")
    end)
  end)
end)

test.finish()
