package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local errors = require("toss.errors")
local result = require("toss.result")

local api_module = "toss.telescope.api"
local path_module = "toss.context.path"
local origin_module = "toss.context.origin.telescope_file_browser"

local fake_api = {}
local fake_path = {
  relative_or_absolute = function(absolute_path)
    return absolute_path:gsub("^/repo/", "")
  end,
  is_directory = function()
    return false
  end,
}

local function load_origin()
  package.loaded[api_module] = fake_api
  package.loaded[path_module] = fake_path
  package.loaded[origin_module] = nil
  return require(origin_module)
end

local function with_origin(callback)
  local previous_api = package.loaded[api_module]
  local previous_path = package.loaded[path_module]
  local previous_origin = package.loaded[origin_module]
  local origin = load_origin()

  local ok, err = xpcall(function()
    callback(origin)
  end, debug.traceback)

  package.loaded[api_module] = previous_api
  package.loaded[path_module] = previous_path
  package.loaded[origin_module] = previous_origin

  if not ok then
    error(err, 0)
  end
end

local function file_browser_picker()
  return {
    finder = {
      _browse_files = function() end,
    },
  }
end

local function configure_picker(picker, selections, cursor)
  fake_api.active_picker = function()
    return result.ok(picker)
  end
  fake_api.multi_selection = function()
    return result.ok(selections)
  end
  fake_api.cursor_entry = function()
    return result.ok(cursor)
  end
end

test.describe("Telescope file-browser context origin", function()
  test.it("captures the cursor file when there is no multi-selection", function()
    configure_picker(file_browser_picker(), {}, { path = "/repo/README.md", is_dir = false })

    with_origin(function(origin)
      local outcome = origin.capture()

      test.equal(outcome:is_ok(), true)
      test.equal(outcome.value.kind, "file")
      test.equal(outcome.value.path, "README.md")
    end)
  end)

  test.it("captures one selected directory instead of the cursor", function()
    configure_picker(
      file_browser_picker(),
      { { path = "/repo/notes", is_dir = true } },
      { path = "/repo/README.md", is_dir = false }
    )

    with_origin(function(origin)
      local outcome = origin.capture()

      test.equal(outcome:is_ok(), true)
      test.equal(outcome.value.kind, "directory")
      test.equal(outcome.value.path, "notes")
    end)
  end)

  test.it("preserves multi-selection order without adding the cursor", function()
    configure_picker(file_browser_picker(), {
      { value = "/repo/README.md", is_dir = false },
      { absolute_path = "/repo/notes", is_directory = true },
    }, { path = "/repo/cursor.lua", is_dir = false })

    with_origin(function(origin)
      local outcome = origin.capture()

      test.equal(outcome:is_ok(), true)
      test.equal(outcome.value.kind, "path_set")
      test.equal(#outcome.value.items, 2)
      test.equal(outcome.value.items[1].kind, "file")
      test.equal(outcome.value.items[1].path, "README.md")
      test.equal(outcome.value.items[2].kind, "directory")
      test.equal(outcome.value.items[2].path, "notes")
    end)
  end)

  test.it("deduplicates identical selected paths while preserving order", function()
    configure_picker(file_browser_picker(), {
      { path = "/repo/README.md", is_dir = false },
      { value = "/repo/README.md", is_dir = false },
      { path = "/repo/notes", is_dir = true },
    }, nil)

    with_origin(function(origin)
      local outcome = origin.capture()

      test.equal(outcome:is_ok(), true)
      test.equal(outcome.value.kind, "path_set")
      test.equal(#outcome.value.items, 2)
      test.equal(outcome.value.items[1].path, "README.md")
      test.equal(outcome.value.items[2].path, "notes")
    end)
  end)

  test.it("uses Path metadata and filesystem fallback for directories", function()
    fake_path.is_directory = function(absolute_path)
      return absolute_path == "/repo/fallback"
    end
    configure_picker(file_browser_picker(), {
      {
        Path = {
          absolute = function()
            return "/repo/path-object"
          end,
          is_dir = function()
            return true
          end,
        },
      },
      { path = "/repo/fallback" },
    }, nil)

    with_origin(function(origin)
      local outcome = origin.capture()

      test.equal(outcome:is_ok(), true)
      test.equal(outcome.value.kind, "path_set")
      test.equal(outcome.value.items[1].kind, "directory")
      test.equal(outcome.value.items[1].path, "path-object")
      test.equal(outcome.value.items[2].kind, "directory")
      test.equal(outcome.value.items[2].path, "fallback")
    end)
  end)

  test.it("rejects a picker that is not file-browser", function()
    configure_picker({ finder = {} }, {}, { path = "/repo/README.md" })

    with_origin(function(origin)
      local outcome = origin.capture()

      test.equal(outcome:is_err(), true)
      test.equal(outcome.error.code, errors.codes.telescope_file_browser_picker)
    end)
  end)

  test.it("rejects entries without an absolute path", function()
    configure_picker(file_browser_picker(), {}, { value = "README.md" })

    with_origin(function(origin)
      local outcome = origin.capture()

      test.equal(outcome:is_err(), true)
      test.equal(outcome.error.code, errors.codes.telescope_file_browser_entry)
      test.contains(errors.message(outcome.error), "usable absolute path")
    end)
  end)
end)

test.finish()
