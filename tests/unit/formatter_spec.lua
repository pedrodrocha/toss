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

  test.it("formats a single diagnostic with ordered metadata", function()
    local formatted = reference.format({
      kind = "diagnostic",
      path = "src/domain/user.lua",
      start_line = 42,
      end_line = 43,
      severity = "error",
      source = "lua_ls",
      code = 1001,
      message = "unknown field",
    })

    test.equal(formatted:is_ok(), true)
    test.equal(formatted.value, "@src/domain/user.lua#L42-L43 — [error lua_ls 1001] unknown field")
  end)

  test.it("formats same-range diagnostic sets under one ranged reference", function()
    local formatted = reference.format({
      kind = "diagnostic_set",
      items = {
        {
          kind = "diagnostic",
          path = "src/main.lua",
          start_line = 8,
          end_line = 8,
          severity = "error",
          message = "undefined name",
        },
        {
          kind = "diagnostic",
          path = "src/main.lua",
          start_line = 8,
          end_line = 8,
          source = "lua_ls",
          message = "  second\n\tmessage  ",
        },
      },
    })

    test.equal(formatted:is_ok(), true)
    test.equal(formatted.value, "@src/main.lua#L8-L8\n[error] undefined name\n[lua_ls] second message")
  end)

  test.it("formats same-file diagnostic sets with a range per item", function()
    local formatted = reference.format({
      kind = "diagnostic_set",
      items = {
        {
          kind = "diagnostic",
          path = "src/main.lua",
          start_line = 8,
          end_line = 9,
          message = "unexpected token",
        },
        {
          kind = "diagnostic",
          path = "src/main.lua",
          start_line = 20,
          end_line = 20,
          severity = "warning",
          message = "unused variable",
        },
      },
    })

    test.equal(formatted:is_ok(), true)
    test.equal(formatted.value, "@src/main.lua\nL8-L9 unexpected token\nL20-L20 [warning] unused variable")
  end)

  test.it("falls back to complete diagnostic references for mixed paths", function()
    local formatted = reference.format({
      kind = "diagnostic_set",
      items = {
        {
          kind = "diagnostic",
          path = "src/first.lua",
          start_line = 3,
          end_line = 3,
          message = "first issue",
        },
        {
          kind = "diagnostic",
          path = "src/second.lua",
          start_line = 12,
          end_line = 14,
          code = "E2",
          message = "second issue",
        },
      },
    })

    test.equal(formatted:is_ok(), true)
    test.equal(formatted.value, "@src/first.lua#L3-L3 — first issue\n@src/second.lua#L12-L14 — [E2] second issue")
  end)

  test.it("omits diagnostic metadata when none is provided", function()
    local formatted = reference.format({
      kind = "diagnostic",
      path = "src/main.lua",
      start_line = 4,
      end_line = 4,
      message = "simple message",
    })

    test.equal(formatted:is_ok(), true)
    test.equal(formatted.value, "@src/main.lua#L4-L4 — simple message")
  end)

  test.it("normalizes repeated whitespace in diagnostic messages", function()
    local formatted = reference.format({
      kind = "diagnostic",
      path = "src/main.lua",
      start_line = 4,
      end_line = 4,
      message = "  first\n\tsecond   third  ",
    })

    test.equal(formatted:is_ok(), true)
    test.equal(formatted.value, "@src/main.lua#L4-L4 — first second third")
  end)

  test.it("rejects invalid single and set diagnostic contexts", function()
    local invalid_contexts = {
      { kind = "diagnostic" },
      { kind = "diagnostic", path = "src/a.lua", start_line = 0, end_line = 1, message = "bad" },
      { kind = "diagnostic", path = "src/a.lua", start_line = 2, end_line = 1, message = "bad" },
      { kind = "diagnostic", path = "src/a.lua", start_line = 1, end_line = 1, message = false },
      { kind = "diagnostic", path = "src/a.lua", start_line = 1, end_line = 1, severity = {}, message = "bad" },
      { kind = "diagnostic", path = "src/a.lua", start_line = 1, end_line = 1, code = {}, message = "bad" },
      { kind = "diagnostic_set", items = {} },
      {
        kind = "diagnostic_set",
        items = { { kind = "file", path = "src/a.lua", start_line = 1, end_line = 1, message = "bad" } },
      },
    }

    for _, context in ipairs(invalid_contexts) do
      local formatted = reference.format(context)
      test.equal(formatted:is_err(), true)
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

  test.it("formats diagnostic contexts through the public facade", function()
    local formatted = formatter.format({
      kind = "diagnostic",
      path = "src/main.lua",
      start_line = 9,
      end_line = 9,
      message = "missing value",
    })

    test.equal(formatted:is_ok(), true)
    test.equal(formatted.value, "@src/main.lua#L9-L9 — missing value")
  end)
end)

test.finish()
