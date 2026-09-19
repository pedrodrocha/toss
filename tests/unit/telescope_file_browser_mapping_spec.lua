package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")

local module_name = "toss.integrations.telescope.file_browser"

local function load_helper()
  package.loaded[module_name] = nil
  return require(module_name)
end

local function with_toss(fake_toss, callback)
  local previous_toss = package.loaded.toss
  package.loaded.toss = fake_toss

  local ok, err = xpcall(callback, debug.traceback)
  package.loaded.toss = previous_toss

  if not ok then
    error(err, 0)
  end
end

local function callback_for(action)
  if type(action) == "function" then
    return action
  end

  if
    type(action) == "table"
    and type(getmetatable(action)) == "table"
    and type(getmetatable(action).__call) == "function"
  then
    return function()
      return action()
    end
  end

  return nil
end

test.describe("Telescope file-browser mapping helper", function()
  test.it("loads without loading Toss or Telescope", function()
    local previous_toss = package.loaded.toss
    package.loaded.toss = nil

    local helper = load_helper()

    test.truthy(helper)
    test.equal(package.loaded.toss, nil)
    package.loaded.toss = previous_toss
  end)

  test.it("returns default mappings for Normal mode and an empty Insert mode table", function()
    local mappings = load_helper().mappings()
    local normal_keys = { "<leader>th", "<leader>tj", "<leader>tk", "<leader>tl" }

    test.truthy(type(mappings.n) == "table")
    test.truthy(type(mappings.i) == "table")
    for _, key in ipairs(normal_keys) do
      test.truthy(type(callback_for(mappings.n[key])) == "function")
      test.contains(mappings.n[key][1], "Toss")
    end
    test.equal(next(mappings.i), nil)
  end)

  test.it("calls the matching Toss direction with the file-browser origin", function()
    local calls = {}
    local fake_toss = {}
    for _, direction in ipairs({ "left", "down", "up", "right" }) do
      fake_toss[direction] = function(origin)
        calls[#calls + 1] = { direction = direction, origin = origin }
        return direction
      end
    end

    local mappings = load_helper().mappings()
    local expected = {
      n = {
        ["<leader>th"] = "left",
        ["<leader>tj"] = "down",
        ["<leader>tk"] = "up",
        ["<leader>tl"] = "right",
      },
    }

    with_toss(fake_toss, function()
      for mode, mode_mappings in pairs(expected) do
        for key, direction in pairs(mode_mappings) do
          test.equal(callback_for(mappings[mode][key])(), direction)
        end
      end
    end)

    test.equal(#calls, 4)
    for _, call in ipairs(calls) do
      test.equal(call.origin, "telescope_file_browser")
    end
  end)
end)

test.finish()
