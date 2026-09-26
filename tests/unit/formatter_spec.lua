package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local formatter = require("toss.formatter")
local reference = require("toss.formatter.reference")
local paths = require("toss.formatter.reference.paths")
local text = require("toss.formatter.reference.text")
local diagnostic = require("toss.formatter.reference.diagnostic")

test.describe("reference formatter orchestration", function()
  test.it("dispatches each context kind to its focused formatter", function()
    local calls = {}
    local results = {
      paths = { formatter = "paths" },
      text = { formatter = "text" },
      diagnostic = { formatter = "diagnostic" },
    }
    local contexts = {
      { kind = "file" },
      { kind = "directory" },
      { kind = "path_set" },
      { kind = "text" },
      { kind = "diagnostic" },
      { kind = "diagnostic_set" },
    }
    local expected = { "paths", "paths", "paths", "text", "diagnostic", "diagnostic" }
    local originals = {}

    local function stub(module, name)
      originals[module] = module.format
      module.format = function(ctx)
        calls[#calls + 1] = { name = name, context = ctx }
        return results[name]
      end
    end

    stub(paths, "paths")
    stub(text, "text")
    stub(diagnostic, "diagnostic")

    local formatted = {}
    for index, context in ipairs(contexts) do
      formatted[index] = reference.format(context)
    end

    for module, original in pairs(originals) do
      module.format = original
    end

    for index, context in ipairs(contexts) do
      test.equal(calls[index].name, expected[index])
      test.equal(calls[index].context, context)
      test.equal(formatted[index], results[expected[index]])
    end
  end)

  test.it("returns Toss errors for invalid and unsupported contexts", function()
    ---@type any
    local invalid_context = nil
    ---@type any
    local unsupported_context = { kind = "unknown" }

    test.equal(reference.format(invalid_context):is_err(), true)
    test.equal(reference.format(unsupported_context):is_err(), true)
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

  test.it("formats each context family through the public facade", function()
    local contexts = {
      { kind = "file", path = "src/main.lua" },
      { kind = "directory", path = "notes" },
      {
        kind = "path_set",
        items = {
          { kind = "file", path = "README.md" },
          { kind = "directory", path = "notes" },
        },
      },
      { kind = "text", text = "literal text" },
      {
        kind = "diagnostic",
        path = "src/main.lua",
        start_line = 9,
        end_line = 9,
        message = "missing value",
      },
      {
        kind = "diagnostic_set",
        items = {
          {
            kind = "diagnostic",
            path = "src/main.lua",
            start_line = 10,
            end_line = 10,
            message = "first issue",
          },
          {
            kind = "diagnostic",
            path = "src/main.lua",
            start_line = 10,
            end_line = 10,
            message = "second issue",
          },
        },
      },
    }
    local expected = {
      "@src/main.lua",
      "@notes/",
      "@README.md @notes/",
      "literal text",
      "@src/main.lua#L9-L9 — missing value",
      "@src/main.lua#L10-L10\nfirst issue\nsecond issue",
    }

    for index, context in ipairs(contexts) do
      local formatted = formatter.format(context)
      test.equal(formatted:is_ok(), true)
      test.equal(formatted.value, expected[index])
    end
  end)
end)

test.finish()
