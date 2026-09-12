package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local which_key = require("toss.which_key")

local function with_which_key(loader, callback)
  local previous_loaded = package.loaded["which-key"]
  local previous_preload = package.preload["which-key"]

  package.loaded["which-key"] = nil
  package.preload["which-key"] = loader

  local ok, err = xpcall(callback, debug.traceback)

  package.loaded["which-key"] = previous_loaded
  package.preload["which-key"] = previous_preload

  if not ok then
    error(err, 0)
  end
end

test.describe("toss which-key integration", function()
  test.it("registers the toss group with the modern API", function()
    local registration

    with_which_key(function()
      return {
        add = function(value)
          registration = value
        end,
      }
    end, function()
      local ok, err = which_key.setup(true)

      test.equal(ok, true)
      test.equal(err, nil)
    end)

    test.equal(registration[1][1], "<leader>t")
    test.equal(registration[1].group, "toss")
    test.equal(registration[1].icon, "󰧑")
    test.equal(registration[1].mode[1], "n")
    test.equal(registration[1].mode[2], "x")
  end)

  test.it("continues when which-key is unavailable", function()
    with_which_key(function()
      error("module not found")
    end, function()
      local ok, err = which_key.setup(true)

      test.equal(ok, true)
      test.equal(err, nil)
    end)
  end)

  test.it("does not load which-key when integration is disabled", function()
    local loaded = false

    with_which_key(function()
      loaded = true
      error("which-key should not be loaded")
    end, function()
      local ok, err = which_key.setup(false)

      test.equal(ok, true)
      test.equal(err, nil)
    end)

    test.equal(loaded, false)
  end)
end)

test.finish()
