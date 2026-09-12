package.path = "./?.lua;./?/init.lua;" .. package.path
vim.opt.rtp:prepend(vim.fn.getcwd())

local test = require("tests.testlib")
local toss = require("toss")

local fixture_path = vim.fn.getcwd() .. "/.toss-init-fixture"
vim.fn.writefile({ "first line", "second line" }, fixture_path)
vim.cmd("edit " .. vim.fn.fnameescape(fixture_path))

test.describe("toss directions", function()
  test.it("sends the normal-mode file payload to each direction", function()
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

    local results = {
      toss.left(),
      toss.down(),
      toss.up(),
      toss.right(),
    }

    for _, result in ipairs(results) do
      test.equal(result, true)
    end

    local expected_directions = { "left", "down", "up", "right" }
    test.equal(#calls, #expected_directions)
    for index, direction in ipairs(expected_directions) do
      test.equal(calls[index].direction, direction)
      test.equal(calls[index].text, "@.toss-init-fixture")
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

vim.fn.delete(fixture_path)
test.finish()
