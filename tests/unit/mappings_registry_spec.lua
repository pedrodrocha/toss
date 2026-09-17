package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local registry = require("toss.mappings.registry")
local errors = require("toss.errors")

local function with_vim(fake_vim, callback)
  local previous_vim = _G.vim
  _G.vim = fake_vim

  local ok, err = xpcall(callback, debug.traceback)
  _G.vim = previous_vim

  if not ok then
    error(err, 0)
  end
end

local function make_vim()
  local mappings = {}
  local calls = {
    set = {},
    del = {},
  }
  local fail_key

  local function mapping_id(mode, key)
    return mode .. "\0" .. key
  end

  local fake_vim = {
    fn = {
      maparg = function(key, mode, _, dict)
        local mapping = mappings[mapping_id(mode, key)]
        if mapping == nil then
          return ""
        end
        if dict then
          return { callback = mapping.callback }
        end
        return key
      end,
    },
    keymap = {},
  }

  fake_vim.keymap.set = function(modes, key, callback, options)
    calls.set[#calls.set + 1] = { modes = modes, key = key, callback = callback, options = options }
    if key == fail_key then
      error("set exploded")
    end

    if type(modes) == "string" then
      modes = { modes }
    end
    for _, mode in ipairs(modes) do
      mappings[mapping_id(mode, key)] = { callback = callback }
    end
  end

  fake_vim.keymap.del = function(mode, key)
    calls.del[#calls.del + 1] = { mode = mode, key = key }
    mappings[mapping_id(mode, key)] = nil
  end

  return fake_vim, calls, mappings, function(key)
    fail_key = key
  end
end

local function specification(name, key, direction, origin)
  return {
    name = name,
    key = key,
    direction = direction or "left",
    origin = origin or "file_buffer",
    description = "Toss " .. name,
  }
end

local function with_registry(callback)
  local fake_vim, calls, mappings, fail = make_vim()
  with_vim(fake_vim, function()
    -- Clear state left by a previous example before observing this example's calls.
    registry.register({}, function()
      return true
    end)
    calls.set = {}
    calls.del = {}

    callback(fake_vim, calls, mappings, fail)

    test.equal(
      registry.register({}, function()
        return true
      end):is_ok(),
      true
    )
  end)
end

test.describe("mapping registry", function()
  test.it("registers callbacks that only pass direction and origin to the runner", function()
    with_registry(function(_, calls)
      local run_calls = {}
      local run = function(direction, origin)
        run_calls[#run_calls + 1] = { direction = direction, origin = origin }
        return true
      end

      local setup_result = registry.register({ specification("left", "<leader>th", "left", "yank") }, run)

      test.equal(setup_result:is_ok(), true)
      test.equal(#calls.set, 1)
      test.equal(calls.set[1].modes[1], "n")
      test.equal(calls.set[1].modes[2], "x")
      calls.set[1].callback()
      test.equal(run_calls[1].direction, "left")
      test.equal(run_calls[1].origin, "yank")
    end)
  end)

  test.it("does not repeat an identical setup", function()
    with_registry(function(_, calls)
      local run = function()
        return true
      end
      local specs = { specification("left", "<leader>th") }

      test.equal(registry.register(specs, run):is_ok(), true)
      calls.set = {}
      calls.del = {}
      test.equal(registry.register(specs, run):is_ok(), true)

      test.equal(#calls.set, 0)
      test.equal(#calls.del, 0)
    end)
  end)

  test.it("removes the old owned mappings before replacing them", function()
    with_registry(function(_, calls)
      local run = function()
        return true
      end

      test.equal(registry.register({ specification("old", "<leader>told") }, run):is_ok(), true)
      calls.set = {}
      calls.del = {}
      test.equal(registry.register({ specification("new", "<leader>tnew") }, run):is_ok(), true)

      test.equal(#calls.del, 2)
      test.equal(calls.del[1].mode, "n")
      test.equal(calls.del[1].key, "<leader>told")
      test.equal(calls.del[2].mode, "x")
      test.equal(calls.del[2].key, "<leader>told")
      test.equal(#calls.set, 1)
      test.equal(calls.set[1].key, "<leader>tnew")
    end)
  end)

  test.it("removes all owned mappings when given an empty set", function()
    with_registry(function(_, calls)
      local run = function()
        return true
      end

      test.equal(registry.register({ specification("left", "<leader>th") }, run):is_ok(), true)
      calls.del = {}
      test.equal(registry.register({}, run):is_ok(), true)

      test.equal(#calls.del, 2)
      test.equal(calls.del[1].mode, "n")
      test.equal(calls.del[2].mode, "x")
    end)
  end)

  test.it("rolls back mappings installed before a registration failure", function()
    with_registry(function(_, calls, mappings, fail)
      local run = function()
        return true
      end
      fail("<leader>tsecond")

      local setup_result = registry.register({
        specification("first", "<leader>tfirst"),
        specification("second", "<leader>tsecond"),
      }, run)

      test.equal(setup_result:is_err(), true)
      test.contains(errors.message(setup_result.error), "could not register second mapping")
      test.equal(#calls.del, 2)
      test.equal(calls.del[1].key, "<leader>tfirst")
      test.equal(calls.del[2].key, "<leader>tfirst")
      test.equal(mappings["n\0<leader>tfirst"], nil)
      test.equal(mappings["x\0<leader>tfirst"], nil)
    end)
  end)

  test.it("does not delete mappings that a user replaced", function()
    with_registry(function(fake_vim, calls, mappings)
      local run = function()
        return true
      end
      local key = "<leader>towned"

      test.equal(registry.register({ specification("owned", key) }, run):is_ok(), true)
      local user_callback = function() end
      fake_vim.keymap.set("n", key, user_callback, {})
      calls.del = {}

      test.equal(registry.register({ specification("replacement", "<leader>tnew") }, run):is_ok(), true)

      test.equal(#calls.del, 1)
      test.equal(calls.del[1].mode, "x")
      test.equal(calls.del[1].key, key)
      test.equal(mappings["n\0" .. key].callback, user_callback)
    end)
  end)
end)

test.finish()
