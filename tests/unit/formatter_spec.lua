package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local errors = require("toss.errors")
local formatter = require("toss.formatter")

test.describe("formatter", function()
  test.it("formats a file-only context", function()
    local formatted = formatter.format({ path = "src/domain/user.lua" })

    test.equal(formatted:is_ok(), true)
    test.equal(formatted.value, "@src/domain/user.lua")
  end)

  test.it("formats a ranged context", function()
    local formatted = formatter.format({
      path = "src/domain/user.lua",
      start_line = 42,
      end_line = 67,
    })

    test.equal(formatted:is_ok(), true)
    test.equal(formatted.value, "@src/domain/user.lua#L42-L67")
  end)

  test.it("passes literal register text through unchanged", function()
    local text = "first line\nsecond line\n"
    local formatted = formatter.format({ text = text })

    test.equal(formatted:is_ok(), true)
    test.equal(formatted.value, text)
  end)

  test.it("rejects empty literal register text", function()
    local formatted = formatter.format({ text = "" })

    test.equal(formatted:is_err(), true)
    test.equal(errors.message(formatted.error), "context text must be a non-empty string")
  end)

  test.it("returns an error for invalid or incomplete context", function()
    local invalid_contexts = {
      nil,
      {},
      { path = "src/file.lua", start_line = 4 },
      { path = "src/file.lua", start_line = 4, end_line = 2 },
      { path = "src/file.lua", start_line = "4", end_line = 8 },
    }

    for _, value in ipairs(invalid_contexts) do
      local formatted = formatter.format(value)

      test.equal(formatted:is_err(), true)
      test.truthy(errors.is(formatted.error))
      test.truthy(type(errors.message(formatted.error)) == "string")
    end
  end)
end)

test.finish()
