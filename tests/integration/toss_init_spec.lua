package.path = "./?.lua;./?/init.lua;" .. package.path
vim.opt.rtp:prepend(vim.fn.getcwd())

local test = require("tests.testlib")
local toss = require("toss")

test.describe("toss directions", function()
  test.it("notify without raising an error", function()
    local notifications = {}
    local previous_notify = vim.notify
    rawset(vim, "notify", function(message, level)
      notifications[#notifications + 1] = { message = message, level = level }
    end)

    local results = {
      toss.left(),
      toss.down(),
      toss.up(),
      toss.right(),
    }

    rawset(vim, "notify", previous_notify)

    for _, result in ipairs(results) do
      test.equal(result, false)
    end

    test.equal(#notifications, 4)
    for _, notification in ipairs(notifications) do
      test.equal(notification.message, "toss: not implemented yet")
      test.equal(notification.level, vim.log.levels.INFO)
    end
  end)
end)

test.describe("toss mappings", function()
  test.it("does not create default mappings", function()
    test.equal(vim.fn.maparg("<leader>th", "n"), "")
    test.equal(vim.fn.maparg("<leader>tj", "n"), "")
    test.equal(vim.fn.maparg("<leader>tk", "n"), "")
    test.equal(vim.fn.maparg("<leader>tl", "n"), "")
  end)
end)

test.finish()
