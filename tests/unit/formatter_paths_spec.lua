package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local paths = require("toss.formatter.reference.paths")

test.describe("path reference formatter", function()
  test.it("formats file-only and ranged file contexts", function()
    local file = paths.format({ kind = "file", path = "src/domain/user.lua" })
    local range = paths.format({
      kind = "file",
      path = "src/domain/user.lua",
      start_line = 42,
      end_line = 67,
    })

    test.equal(file:is_ok(), true)
    test.equal(file.value, "@src/domain/user.lua")
    test.equal(range:is_ok(), true)
    test.equal(range.value, "@src/domain/user.lua#L42-L67")
  end)

  test.it("formats directories with exactly one trailing slash", function()
    for _, path in ipairs({ "notes", "notes/", "notes///" }) do
      local formatted = paths.format({ kind = "directory", path = path })

      test.equal(formatted:is_ok(), true)
      test.equal(formatted.value, "@notes/")
    end
  end)

  test.it("formats path sets in order with single-space separators", function()
    local formatted = paths.format({
      kind = "path_set",
      items = {
        { kind = "file", path = "README.md" },
        { kind = "directory", path = "notes/" },
        { kind = "file", path = "lua/toss/init.lua" },
      },
    })

    test.equal(formatted:is_ok(), true)
    test.equal(formatted.value, "@README.md @notes/ @lua/toss/init.lua")
  end)
end)

test.finish()
