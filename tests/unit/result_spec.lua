package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local errors = require("toss.errors")
local result = require("toss.result")

test.describe("toss results", function()
  test.it("represents successful values", function()
    local outcome = result.ok("payload")

    test.equal(outcome.kind, "ok")
    test.equal(outcome.value, "payload")
    test.equal(result.is(outcome), true)
  end)

  test.it("represents errors without using a nil result sentinel", function()
    local error_value = errors.buffer_not_file()
    local outcome = result.err(error_value)

    test.equal(outcome.kind, "err")
    test.equal(outcome.error, error_value)
    test.equal(result.is(outcome), true)
  end)
end)

test.finish()
