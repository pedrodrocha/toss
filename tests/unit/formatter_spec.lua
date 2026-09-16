package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local errors = require("toss.errors")
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

  test.it("passes literal register text through unchanged", function()
    local text = "first line\nsecond line\n"
    local formatted = reference.format({ kind = "text", text = text })

    test.equal(formatted:is_ok(), true)
    test.equal(formatted.value, text)
  end)

  test.it("rejects empty literal register text", function()
    local formatted = reference.format({ kind = "text", text = "" })

    test.equal(formatted:is_err(), true)
    test.equal(errors.message(formatted.error), "context text must be a non-empty string")
  end)

  test.it("rejects a missing or unknown context kind", function()
    for _, value in ipairs({
      { path = "src/file.lua" },
      { kind = "unknown", path = "src/file.lua" },
    }) do
      local formatted = reference.format(value)

      test.equal(formatted:is_err(), true)
      test.truthy(errors.is(formatted.error))
      test.equal(formatted.error.code, errors.codes.context_kind)
    end
  end)

  test.it("returns an error for invalid or incomplete context", function()
    local invalid_contexts = {
      {},
      { kind = "file" },
      { kind = "text" },
      { kind = "file", path = "src/file.lua", start_line = 4 },
      { kind = "file", path = "src/file.lua", start_line = 4, end_line = 2 },
      { kind = "file", path = "src/file.lua", start_line = "4", end_line = 8 },
      { kind = "file", path = 42 },
      { kind = "text", text = 42 },
    }

    local formatted_nil = reference.format(nil)
    test.equal(formatted_nil:is_err(), true)
    test.truthy(errors.is(formatted_nil.error))

    for _, value in ipairs(invalid_contexts) do
      local formatted = reference.format(value)

      test.equal(formatted:is_err(), true)
      test.truthy(errors.is(formatted.error))
      test.truthy(type(errors.message(formatted.error)) == "string")
    end
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
