package.path = "./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")

test.run("unit test runner executes assertions", function()
  test.equal(2 + 2, 4)
  test.truthy(true)
end)

test.finish()
