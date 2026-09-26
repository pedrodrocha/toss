package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local text_formatter = require("toss.formatter.reference.text")

test.describe("text reference formatter", function()
  test.it("passes literal text through unchanged", function()
    local text = "first line\nsecond line\n"
    local formatted = text_formatter.format({ kind = "text", text = text })

    test.equal(formatted:is_ok(), true)
    test.equal(formatted.value, text)
  end)
end)

test.finish()
