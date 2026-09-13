package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local errors = require("toss.errors")
local herdr = require("toss.transports.herdr")

local function with_vim(fake_vim, callback)
  local previous_vim = _G.vim
  _G.vim = fake_vim

  local ok, err = xpcall(callback, debug.traceback)
  _G.vim = previous_vim

  if not ok then
    error(err, 0)
  end
end

local function assert_success(outcome)
  test.equal(outcome.kind, "ok")
  return assert(outcome.value)
end

local function assert_failure(outcome)
  test.equal(outcome.kind, "err")
  return assert(outcome.error)
end

local function fake_herdr(options)
  options = options or {}

  local calls = {}
  local neighbor_response = options.neighbor_response
    or {
      result = {
        neighbor = {
          neighbor_pane_id = "destination-pane",
        },
      },
    }
  local neighbor_result = options.neighbor_result
    or {
      code = 0,
      stdout = "neighbor response",
      stderr = "",
    }
  local send_result = options.send_result or {
    code = 0,
    stdout = "",
    stderr = "",
  }
  local focus_result = options.focus_result or {
    code = 0,
    stdout = "",
    stderr = "",
  }
  local fake_vim = {
    env = {
      HERDR_ENV = "1",
      HERDR_PANE_ID = "source-pane",
    },
    json = {
      decode = function(value)
        test.equal(value, "neighbor response")
        return neighbor_response
      end,
    },
    system = function(argv)
      calls[#calls + 1] = argv
      local command_results = {
        neighbor = neighbor_result,
        ["send-text"] = send_result,
        focus = focus_result,
      }
      local command_result = command_results[argv[3]]

      return {
        wait = function()
          return command_result
        end,
      }
    end,
  }

  return fake_vim, calls
end

test.describe("Herdr transport focus", function()
  test.it("focuses the explicit source pane in every direction", function()
    local directions = { "left", "down", "up", "right" }

    for _, direction in ipairs(directions) do
      local fake_vim, calls = fake_herdr()

      with_vim(fake_vim, function()
        local focus_result = herdr.focus(direction)

        test.equal(focus_result.kind, "ok")
      end)

      test.equal(#calls, 1)
      local expected_argv = {
        "herdr",
        "pane",
        "focus",
        "--pane",
        "source-pane",
        "--direction",
        direction,
      }
      for index, argument in ipairs(expected_argv) do
        test.equal(calls[1][index], argument)
      end
    end
  end)

  test.it("reports focus command failures with useful details", function()
    local fake_vim, calls = fake_herdr({
      focus_result = {
        code = 1,
        stdout = "pane_not_found",
        stderr = "source pane is invalid\\n",
      },
    })

    with_vim(fake_vim, function()
      local err = assert_failure(herdr.focus("right"))

      test.contains(errors.message(err), "Herdr focus failed")
      test.contains(errors.message(err), "exit code 1")
      test.contains(errors.message(err), "source pane is invalid")
      test.contains(errors.message(err), "pane_not_found")
    end)

    test.equal(#calls, 1)
  end)

  test.it("rejects focus without a valid Herdr environment", function()
    local calls = 0

    with_vim({
      env = { HERDR_ENV = "0", HERDR_PANE_ID = "source-pane" },
      system = function()
        calls = calls + 1
      end,
    }, function()
      local err = assert_failure(herdr.focus("left"))

      test.contains(errors.message(err), "requires Neovim to run inside Herdr")
    end)

    test.equal(calls, 0)
  end)
end)

test.describe("Herdr transport availability", function()
  test.it("is available inside a Herdr pane", function()
    with_vim({
      env = {
        HERDR_ENV = "1",
        HERDR_PANE_ID = "source-pane",
      },
    }, function()
      test.equal(herdr.available(), true)
    end)
  end)

  test.it("is unavailable without a valid Herdr environment", function()
    local environments = {
      {},
      { HERDR_ENV = "0", HERDR_PANE_ID = "source-pane" },
      { HERDR_ENV = "1" },
    }

    for _, env in ipairs(environments) do
      with_vim({ env = env }, function()
        test.equal(herdr.available(), false)
      end)
    end
  end)
end)

test.describe("Herdr transport neighbor lookup", function()
  test.it("rejects a missing Herdr environment", function()
    local system_calls = 0

    with_vim({
      env = { HERDR_ENV = "0", HERDR_PANE_ID = "source-pane" },
      system = function()
        system_calls = system_calls + 1
      end,
    }, function()
      local err = assert_failure(herdr.neighbor("right"))

      test.contains(errors.message(err), "requires Neovim to run inside Herdr")
    end)

    test.equal(system_calls, 0)
  end)

  test.it("rejects a missing source pane ID", function()
    with_vim({
      env = { HERDR_ENV = "1" },
      system = function()
        error("the CLI should not run")
      end,
    }, function()
      local err = assert_failure(herdr.neighbor("left"))

      test.contains(errors.message(err), "requires HERDR_PANE_ID")
    end)
  end)

  test.it("resolves a neighbor using the caller pane ID", function()
    local fake_vim, calls = fake_herdr({
      neighbor_response = {
        result = {
          neighbor = {
            neighbor_pane_id = "destination-pane",
          },
        },
      },
    })

    with_vim(fake_vim, function()
      local pane_id = assert_success(herdr.neighbor("down"))

      test.equal(pane_id, "destination-pane")
    end)

    test.equal(#calls, 1)
    local expected_argv = {
      "herdr",
      "pane",
      "neighbor",
      "--pane",
      "source-pane",
      "--direction",
      "down",
    }
    for index, argument in ipairs(expected_argv) do
      test.equal(calls[1][index], argument)
    end
  end)

  test.it("reports a missing neighbor without panicking", function()
    local responses = {
      { result = { neighbor = {} } },
      { result = {} },
    }

    for _, response in ipairs(responses) do
      local fake_vim = fake_herdr({ neighbor_response = response })

      with_vim(fake_vim, function()
        local err = assert_failure(herdr.neighbor("up"))

        test.contains(errors.message(err), "no adjacent Herdr pane")
      end)
    end
  end)

  test.it("reports Herdr process spawn failures without panicking", function()
    local fake_vim = {
      env = {
        HERDR_ENV = "1",
        HERDR_PANE_ID = "source-pane",
      },
      system = function()
        error("herdr executable not found")
      end,
    }

    with_vim(fake_vim, function()
      local err = assert_failure(herdr.neighbor("left"))

      test.equal(err.code, errors.codes.herdr_spawn)
      test.contains(errors.message(err), "could not start Herdr neighbor lookup")
      test.contains(errors.message(err), "herdr executable not found")
    end)
  end)

  test.it("reports malformed neighbor responses without panicking", function()
    local fake_vim = {
      env = {
        HERDR_ENV = "1",
        HERDR_PANE_ID = "source-pane",
      },
      json = {
        decode = function()
          error("invalid JSON")
        end,
      },
      system = function()
        return {
          wait = function()
            return { code = 0, stdout = "invalid response", stderr = "" }
          end,
        }
      end,
    }

    with_vim(fake_vim, function()
      local err = assert_failure(herdr.neighbor("left"))

      test.equal(err.code, errors.codes.herdr_response)
      test.contains(errors.message(err), "could not decode Herdr neighbor response")
      test.contains(errors.message(err), "invalid JSON")
    end)
  end)

  test.it("includes CLI output when the neighbor command fails", function()
    local fake_vim = {
      env = {
        HERDR_ENV = "1",
        HERDR_PANE_ID = "source-pane",
      },
      system = function()
        return {
          wait = function()
            return {
              code = 1,
              stdout = "pane_not_found",
              stderr = "source pane is invalid\n",
            }
          end,
        }
      end,
    }

    with_vim(fake_vim, function()
      local err = assert_failure(herdr.neighbor("left"))

      test.contains(errors.message(err), "exit code 1")
      test.contains(errors.message(err), "source pane is invalid")
      test.contains(errors.message(err), "pane_not_found")
    end)
  end)
end)

test.describe("Herdr transport send-text", function()
  test.it("resolves the neighbor and sends text as one argument", function()
    local fake_vim, calls = fake_herdr()
    local text = "@src/file.lua#L2-L4; printf hacked"

    with_vim(fake_vim, function()
      local send_result = herdr.send("right", text)

      test.equal(send_result.kind, "ok")
    end)

    test.equal(#calls, 2)
    test.equal(calls[1][3], "neighbor")
    test.equal(calls[2][1], "herdr")
    test.equal(calls[2][2], "pane")
    test.equal(calls[2][3], "send-text")
    test.equal(calls[2][4], "destination-pane")
    test.equal(calls[2][5], text)
    test.equal(#calls[2], 5)
  end)

  test.it("reports send-text CLI failures with useful details", function()
    local fake_vim, calls = fake_herdr({
      send_result = {
        code = 1,
        stdout = "pane_not_found",
        stderr = "destination pane is invalid\n",
      },
    })

    with_vim(fake_vim, function()
      local err = assert_failure(herdr.send("left", "@src/file.lua"))

      test.contains(errors.message(err), "Herdr send-text failed")
      test.contains(errors.message(err), "exit code 1")
      test.contains(errors.message(err), "destination pane is invalid")
      test.contains(errors.message(err), "pane_not_found")
    end)

    test.equal(#calls, 2)
  end)

  test.it("does not send when no neighbor is found", function()
    local fake_vim, calls = fake_herdr({
      neighbor_response = { result = { neighbor = {} } },
    })

    with_vim(fake_vim, function()
      local err = assert_failure(herdr.send("up", "@src/file.lua"))

      test.contains(errors.message(err), "no adjacent Herdr pane")
    end)

    test.equal(#calls, 1)
  end)

  test.it("rejects non-string text before invoking Herdr", function()
    local calls = 0
    local fake_vim = {
      env = {
        HERDR_ENV = "1",
        HERDR_PANE_ID = "source-pane",
      },
      system = function()
        calls = calls + 1
      end,
    }

    with_vim(fake_vim, function()
      ---@type any
      local invalid_text = nil
      local err = assert_failure(herdr.send("right", invalid_text))

      test.contains(errors.message(err), "requires text")
    end)

    test.equal(calls, 0)
  end)
end)

test.finish()
