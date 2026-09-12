package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local toss = require("toss")

test.run("unit test runner executes assertions", function()
  test.equal(2 + 2, 4)
  test.truthy(true)
end)

test.run("setup merges configuration and returns the module", function()
  toss.config = {}

  test.equal(toss.setup({ first = true }), toss)
  toss.setup({ second = "value" })

  test.equal(toss.config.first, true)
  test.equal(toss.config.second, "value")
end)

test.run("direction stubs notify without raising an error", function()
  local notifications = {}
  local previous_vim = _G.vim
  _G.vim = {
    log = { levels = { INFO = "info" } },
    notify = function(message, level)
      notifications[#notifications + 1] = { message = message, level = level }
    end,
  }

  test.equal(toss.left(), false)
  test.equal(toss.down(), false)
  test.equal(toss.up(), false)
  test.equal(toss.right(), false)

  _G.vim = previous_vim

  test.equal(#notifications, 4)
  for _, notification in ipairs(notifications) do
    test.equal(notification.message, "toss: not implemented yet")
    test.equal(notification.level, "info")
  end
end)

test.finish()
