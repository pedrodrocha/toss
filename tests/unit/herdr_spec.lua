package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local herdr = require("toss.transports.herdr")

local function contains(value, fragment)
  return type(value) == "string" and string.find(value, fragment, 1, true) ~= nil
end

local function with_vim(fake_vim, callback)
  local previous_vim = _G.vim
  _G.vim = fake_vim

  local ok, err = xpcall(callback, debug.traceback)
  _G.vim = previous_vim

  if not ok then
    error(err, 0)
  end
end

local function fake_transport(response)
  local calls = {}
  local fake_vim = {
    env = {
      HERDR_ENV = "1",
      HERDR_PANE_ID = "source-pane",
    },
    json = {
      decode = function(value)
        test.equal(value, "neighbor response")
        return response
      end,
    },
    system = function(argv)
      calls[#calls + 1] = argv
      return {
        wait = function()
          return {
            code = 0,
            stdout = "neighbor response",
            stderr = "",
          }
        end,
      }
    end,
  }

  return fake_vim, calls
end

test.describe("Herdr transport neighbor lookup", function()
  test.it("rejects a missing Herdr environment", function()
    local system_calls = 0

    with_vim({
      env = { HERDR_ENV = "0", HERDR_PANE_ID = "source-pane" },
      system = function()
        system_calls = system_calls + 1
      end,
    }, function()
      local pane_id, err = herdr.neighbor("right")

      test.equal(pane_id, nil)
      test.truthy(contains(err, "requires Neovim to run inside Herdr"))
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
      local pane_id, err = herdr.neighbor("left")

      test.equal(pane_id, nil)
      test.truthy(contains(err, "requires HERDR_PANE_ID"))
    end)
  end)

  test.it("resolves a neighbor using the caller pane ID", function()
    local fake_vim, calls = fake_transport({
      result = {
        neighbor = {
          neighbor_pane_id = "destination-pane",
        },
      },
    })

    with_vim(fake_vim, function()
      local pane_id, err = herdr.neighbor("down")

      test.equal(err, nil)
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
      local fake_vim = fake_transport(response)

      with_vim(fake_vim, function()
        local pane_id, err = herdr.neighbor("up")

        test.equal(pane_id, nil)
        test.truthy(contains(err, "no adjacent Herdr pane"))
      end)
    end
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
      local pane_id, err = herdr.neighbor("left")

      test.equal(pane_id, nil)
      test.truthy(contains(err, "exit code 1"))
      test.truthy(contains(err, "source pane is invalid"))
      test.truthy(contains(err, "pane_not_found"))
    end)
  end)
end)

test.finish()
