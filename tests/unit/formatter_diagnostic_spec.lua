package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local diagnostic = require("toss.formatter.reference.diagnostic")

test.describe("diagnostic reference formatter", function()
  test.it("formats a single diagnostic with ordered metadata", function()
    local formatted = diagnostic.format({
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
    local formatted = diagnostic.format({
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
    local formatted = diagnostic.format({
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
    local formatted = diagnostic.format({
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

  test.it("omits metadata when none is provided", function()
    local formatted = diagnostic.format({
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
    local formatted = diagnostic.format({
      kind = "diagnostic",
      path = "src/main.lua",
      start_line = 4,
      end_line = 4,
      message = "  first\n\tsecond   third  ",
    })

    test.equal(formatted:is_ok(), true)
    test.equal(formatted.value, "@src/main.lua#L4-L4 — first second third")
  end)

  test.it("rejects malformed diagnostics and diagnostic sets with Toss errors", function()
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
      local formatted = diagnostic.format(context)
      test.equal(formatted:is_err(), true)
    end
  end)
end)

test.finish()
