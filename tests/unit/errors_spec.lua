package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local errors = require("toss.errors")

test.describe("toss errors", function()
  test.it("builds a warning with a stable code and message", function()
    local err = errors.no_transport()

    test.truthy(errors.is(err))
    test.equal(err.code, errors.codes.no_transport)
    test.equal(err.level, "warn")
    test.equal(errors.message(err), "no transport is available")
  end)

  test.it("builds detailed errors without duplicating the detail", function()
    local err = errors.herdr_command("Herdr send-text failed (exit code 1)", "pane is invalid")

    test.equal(err.level, "error")
    test.equal(errors.message(err), "Herdr send-text failed (exit code 1): pane is invalid")
  end)

  test.it("describes invalid context origins", function()
    local err = errors.invalid_context_origin("other")

    test.equal(err.code, errors.codes.context_origin)
    test.equal(errors.message(err), 'context origin must be "file_buffer", "yank", or "telescope_file_browser": other')
  end)

  test.it("normalizes unsupported levels to errors", function()
    local err = errors.new("example", "example", { level = "info" })

    test.equal(err.level, "error")
  end)
end)

test.finish()
