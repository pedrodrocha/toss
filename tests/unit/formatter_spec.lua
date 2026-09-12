package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local formatter = require("toss.formatter")

test.describe("formatter", function()
  test.it("formats a file-only context", function()
    test.equal(formatter.format({ path = "src/domain/user.lua" }), "@src/domain/user.lua")
  end)

  test.it("formats a ranged context", function()
    test.equal(
      formatter.format({ path = "src/domain/user.lua", start_line = 42, end_line = 67 }),
      "@src/domain/user.lua#L42-L67"
    )
  end)

  test.it("returns an error for invalid or incomplete context", function()
    local invalid_contexts = {
      { value = nil },
      { value = {} },
      { value = { path = "src/file.lua", start_line = 4 } },
      { value = { path = "src/file.lua", start_line = 4, end_line = 2 } },
      { value = { path = "src/file.lua", start_line = "4", end_line = 8 } },
    }

    for _, case in ipairs(invalid_contexts) do
      local ok, payload, err = pcall(formatter.format, case.value)

      test.truthy(ok)
      test.equal(payload, nil)
      test.truthy(type(err) == "string")
    end
  end)
end)

test.finish()
