package.path = "./?.lua;./?/init.lua;" .. package.path
vim.opt.rtp:prepend(vim.fn.getcwd())

local test = require("tests.testlib")
local toss_result = require("toss.result")
local toss = require("toss")
local transports = require("toss.transports")

local fixture_path = vim.fn.getcwd() .. "/.toss-init-fixture"
vim.fn.writefile({ "first line", "second line" }, fixture_path)
vim.cmd("edit " .. vim.fn.fnameescape(fixture_path))

local function with_herdr_environment(callback)
  local previous_env = {
    HERDR_ENV = vim.env.HERDR_ENV,
    HERDR_PANE_ID = vim.env.HERDR_PANE_ID,
  }

  vim.env.HERDR_ENV = "1"
  vim.env.HERDR_PANE_ID = "source-pane"

  local ok, err = xpcall(callback, debug.traceback)
  vim.env.HERDR_ENV = previous_env.HERDR_ENV
  vim.env.HERDR_PANE_ID = previous_env.HERDR_PANE_ID

  if not ok then
    error(err, 0)
  end
end

test.describe("toss directions", function()
  test.it("sends the normal-mode file payload to each direction", function()
    local calls = {}
    toss.config = {}
    toss.setup({
      transport = {
        send = function(direction, text)
          calls[#calls + 1] = { direction = direction, text = text }
          return toss_result.ok()
        end,
      },
    })

    local results = {
      toss.left(),
      toss.down(),
      toss.up(),
      toss.right(),
    }

    for _, outcome in ipairs(results) do
      test.equal(outcome, true)
    end

    local expected_directions = { "left", "down", "up", "right" }
    test.equal(#calls, #expected_directions)
    for index, direction in ipairs(expected_directions) do
      test.equal(calls[index].direction, direction)
      test.equal(calls[index].text, "@.toss-init-fixture")
    end
  end)
end)

test.describe("toss transport configuration", function()
  test.it("selects Herdr by name through the public API", function()
    local calls = {}
    local previous_send = transports.registry.herdr.send
    rawset(transports.registry.herdr, "send", function(direction, text)
      calls[#calls + 1] = { direction = direction, text = text }
      return toss_result.ok()
    end)

    toss.config = {}
    toss.setup({ transport = "herdr" })
    local outcome = toss.right()

    transports.registry.herdr.send = previous_send

    test.equal(outcome, true)
    test.equal(#calls, 1)
    test.equal(calls[1].direction, "right")
    test.equal(calls[1].text, "@.toss-init-fixture")
  end)

  test.it("auto-detects Herdr through the public API", function()
    local calls = {}
    local previous_send = transports.registry.herdr.send
    rawset(transports.registry.herdr, "send", function(direction, text)
      calls[#calls + 1] = { direction = direction, text = text }
      return toss_result.ok()
    end)

    toss.config = {}
    toss.setup({ transport = "auto" })
    with_herdr_environment(function()
      test.equal(toss.right(), true)
    end)

    transports.registry.herdr.send = previous_send

    test.equal(#calls, 1)
    test.equal(calls[1].direction, "right")
    test.equal(calls[1].text, "@.toss-init-fixture")
  end)
end)

test.describe("toss mappings", function()
  test.it("does not create default mappings", function()
    test.equal(vim.fn.maparg("<leader>th", "n"), "")
    test.equal(vim.fn.maparg("<leader>tj", "n"), "")
    test.equal(vim.fn.maparg("<leader>tk", "n"), "")
    test.equal(vim.fn.maparg("<leader>tl", "n"), "")
  end)

  test.it("creates mappings in Normal and Visual mode when enabled", function()
    toss.config = {}
    toss.setup({ mappings = true })

    local keys = { "<leader>th", "<leader>tj", "<leader>tk", "<leader>tl" }
    for _, key in ipairs(keys) do
      test.truthy(vim.fn.maparg(key, "n") ~= "")
      test.truthy(vim.fn.maparg(key, "x") ~= "")
    end
  end)
end)

vim.fn.delete(fixture_path)
test.finish()
