local M = {
  failures = 0,
  passed = 0,
}

local describe_stack = {}

local function qualified_name(name)
  if #describe_stack == 0 then
    return name
  end

  return table.concat(describe_stack, " > ") .. " > " .. name
end

local function value_to_string(value)
  if type(value) == "string" then
    return string.format("%q", value)
  end

  return tostring(value)
end

function M.equal(actual, expected, message)
  if actual ~= expected then
    error(
      message
        or string.format(
          "expected %s, got %s",
          value_to_string(expected),
          value_to_string(actual)
        ),
      2
    )
  end
end

function M.truthy(value, message)
  if not value then
    error(message or "expected a truthy value", 2)
  end
end

function M.run(name, test)
  local ok, err = xpcall(test, debug.traceback)

  if ok then
    M.passed = M.passed + 1
    print("ok - " .. name)
    return
  end

  M.failures = M.failures + 1
  io.stderr:write("not ok - " .. name .. "\n" .. err .. "\n")
end

function M.it(name, test)
  M.run(qualified_name(name), test)
end

function M.describe(name, suite)
  local full_name = qualified_name(name)
  print("describe - " .. full_name)

  describe_stack[#describe_stack + 1] = name
  local ok, err = xpcall(suite, debug.traceback)
  describe_stack[#describe_stack] = nil

  if not ok then
    M.failures = M.failures + 1
    io.stderr:write("not ok - " .. full_name .. "\n" .. err .. "\n")
  end
end

function M.finish()
  local total = M.passed + M.failures
  print(string.format("%d tests, %d failures", total, M.failures))
  os.exit(M.failures == 0 and 0 or 1)
end

return M
