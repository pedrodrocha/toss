package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local path = require("toss.context.path")
local project_root = require("toss.context.root")

local function with_vim(fake_vim, callback)
  local previous_vim = _G.vim
  _G.vim = fake_vim

  local ok, err = xpcall(callback, debug.traceback)
  _G.vim = previous_vim

  if not ok then
    error(err, 0)
  end
end

local function with_root(resolve, callback)
  local previous_resolve = project_root.resolve
  rawset(project_root, "resolve", resolve)

  local ok, err = xpcall(callback, debug.traceback)
  rawset(project_root, "resolve", previous_resolve)

  if not ok then
    error(err, 0)
  end
end

test.describe("context path helpers", function()
  test.it("prefers a project-relative path", function()
    local resolved_bufnr

    with_root(function(bufnr)
      resolved_bufnr = bufnr
      return "/project"
    end, function()
      with_vim({
        fs = {
          relpath = function(root, absolute_path)
            test.equal(root, "/project")
            test.equal(absolute_path, "/project/lua/toss/init.lua")
            return "lua/toss/init.lua"
          end,
        },
      }, function()
        test.equal(path.relative_or_absolute("/project/lua/toss/init.lua", 7), "lua/toss/init.lua")
      end)
    end)

    test.equal(resolved_bufnr, 7)
  end)

  test.it("falls back to an absolute path when no root is available", function()
    with_root(function()
      return nil
    end, function()
      with_vim({
        fs = {
          relpath = function()
            error("relative paths should not be attempted")
          end,
        },
      }, function()
        test.equal(path.relative_or_absolute("/outside/file.lua"), "/outside/file.lua")
      end)
    end)
  end)

  test.it("falls back to an absolute path when relpath returns no path", function()
    with_root(function()
      return "/project"
    end, function()
      with_vim({
        fs = {
          relpath = function()
            return nil
          end,
        },
      }, function()
        test.equal(path.relative_or_absolute("/outside/file.lua"), "/outside/file.lua")
      end)
    end)
  end)

  test.it("reports directories from filesystem metadata", function()
    with_vim({
      uv = {
        fs_stat = function(absolute_path)
          if absolute_path == "/project/notes" then
            return { type = "directory" }
          end

          if absolute_path == "/project/README.md" then
            return { type = "file" }
          end

          return nil, "ENOENT"
        end,
      },
    }, function()
      test.equal(path.is_directory("/project/notes"), true)
      test.equal(path.is_directory("/project/README.md"), false)
      test.equal(path.is_directory("/project/missing"), false)
    end)
  end)

  test.it("treats stat failures as non-directories", function()
    with_vim({
      uv = {
        fs_stat = function()
          error("stat failed")
        end,
      },
    }, function()
      test.equal(path.is_directory("/project/broken"), false)
    end)
  end)
end)

test.finish()
