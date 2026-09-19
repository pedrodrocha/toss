package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local errors = require("toss.errors")
local api = require("toss.telescope.api")

local action_state_module = "telescope.actions.state"

local function with_action_state(loader, callback)
  local previous_loaded = package.loaded[action_state_module]
  local previous_preload = package.preload[action_state_module]

  package.loaded[action_state_module] = nil
  package.preload[action_state_module] = loader

  local ok, err = xpcall(callback, debug.traceback)
  package.loaded[action_state_module] = previous_loaded
  package.preload[action_state_module] = previous_preload

  if not ok then
    error(err, 0)
  end
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

local function fake_state(picker, entry)
  return {
    get_current_picker = function(prompt_bufnr)
      test.equal(prompt_bufnr, 17)
      return picker
    end,
    get_selected_entry = function()
      return entry
    end,
  }
end

test.describe("Telescope API adapter", function()
  test.it("loads without Telescope installed", function()
    with_action_state(function()
      error("module 'telescope.actions.state' not found")
    end, function()
      local outcome = api.selected_entry()

      test.equal(outcome:is_err(), true)
      test.equal(outcome.error.code, errors.codes.telescope_unavailable)
      test.contains(errors.message(outcome.error), "Telescope is not available")
    end)
  end)

  test.it("returns the active picker, cursor entry, and multi-selection", function()
    local cursor_entry = { value = "cursor.lua" }
    local selected_entries = {
      { value = "first.lua" },
      { value = "second.lua" },
    }
    local picker = {
      get_multi_selection = function(self)
        test.truthy(self ~= nil)
        return selected_entries
      end,
    }

    with_action_state(function()
      return fake_state(picker, cursor_entry)
    end, function()
      local active = api.active_picker(17)
      local cursor = api.selected_entry()
      local multi = api.multi_selection(picker)

      test.equal(active:is_ok(), true)
      test.equal(active.value, picker)
      test.equal(cursor:is_ok(), true)
      test.equal(cursor.value, cursor_entry)
      test.equal(multi:is_ok(), true)
      test.equal(multi.value, selected_entries)
    end)
  end)

  test.it("uses the active picker when reading multi-selection without one", function()
    local picker = {
      get_multi_selection = function()
        return {}
      end,
    }

    with_action_state(function()
      return fake_state(picker, { value = "cursor.lua" })
    end, function()
      with_vim({
        api = {
          nvim_get_current_buf = function()
            return 17
          end,
        },
      }, function()
        local multi = api.multi_selection()

        test.equal(multi:is_ok(), true)
        test.equal(#multi.value, 0)
      end)
    end)
  end)

  test.it("returns a friendly error when there is no active picker", function()
    with_action_state(function()
      return {
        get_current_picker = function()
          return nil
        end,
      }
    end, function()
      local outcome = api.active_picker(17)

      test.equal(outcome:is_err(), true)
      test.equal(outcome.error.code, errors.codes.telescope_picker)
      test.equal(errors.message(outcome.error), "no active Telescope picker found")
    end)
  end)

  test.it("returns a friendly error when there is no cursor entry", function()
    with_action_state(function()
      return {
        get_selected_entry = function()
          return nil
        end,
      }
    end, function()
      local outcome = api.selected_entry()

      test.equal(outcome:is_err(), true)
      test.equal(outcome.error.code, errors.codes.telescope_entry)
      test.equal(errors.message(outcome.error), "no Telescope cursor entry found")
    end)
  end)

  test.it("returns a friendly error when picker state cannot be read", function()
    with_action_state(function()
      return {
        get_current_picker = function()
          error("picker state exploded")
        end,
      }
    end, function()
      local outcome = api.active_picker(17)

      test.equal(outcome:is_err(), true)
      test.equal(outcome.error.code, errors.codes.telescope_picker)
      test.contains(errors.message(outcome.error), "picker state exploded")
    end)
  end)
end)

test.finish()
