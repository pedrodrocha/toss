package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")

test.describe("test runner", function()
  test.it("executes assertions", function()
    test.equal(2 + 2, 4)
    test.truthy(true)
  end)
end)

test.finish()
