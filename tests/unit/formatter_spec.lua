package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local formatter = require("toss.formatter")
local reference = require("toss.formatter.reference")

test.describe("reference formatter", function()
  test.it("formats a file-only context", function()
    local formatted = reference.format({ kind = "file", path = "src/domain/user.lua" })

    test.equal(formatted:is_ok(), true)
    test.equal(formatted.value, "@src/domain/user.lua")
  end)

  test.it("formats a ranged context", function()
    local formatted = reference.format({
      kind = "file",
      path = "src/domain/user.lua",
      start_line = 42,
      end_line = 67,
    })

    test.equal(formatted:is_ok(), true)
    test.equal(formatted.value, "@src/domain/user.lua#L42-L67")
  end)

  test.it("formats directory contexts with exactly one trailing slash", function()
    for _, path in ipairs({ "notes", "notes/", "notes///" }) do
      local formatted = reference.format({ kind = "directory", path = path })

      test.equal(formatted:is_ok(), true)
      test.equal(formatted.value, "@notes/")
    end
  end)

  test.it("formats path sets in order with single-space separators", function()
    local formatted = reference.format({
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

  test.it("passes literal register text through unchanged", function()
    local text = "first line\nsecond line\n"
    local formatted = reference.format({ kind = "text", text = text })

    test.equal(formatted:is_ok(), true)
    test.equal(formatted.value, text)
  end)
end)

test.describe("formatter facade", function()
  test.it("delegates formatting to the reference formatter", function()
    local context = { kind = "file", path = "src/file.lua" }
    local delegated_context
    local delegated_result = { delegated = true }
    local previous_format = reference.format

    rawset(reference, "format", function(value)
      delegated_context = value
      return delegated_result
    end)

    local formatted = formatter.format(context)
    rawset(reference, "format", previous_format)

    test.equal(delegated_context, context)
    test.equal(formatted, delegated_result)
  end)
end)

test.finish()
