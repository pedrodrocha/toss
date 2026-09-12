package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path

local test = require("tests.testlib")
local project_root = require("toss.context.root")

local expected_markers = {
  ".git",
  ".hg",
  ".svn",
  "package.json",
  "Cargo.toml",
  "pyproject.toml",
  "go.work",
  "go.mod",
  "Gemfile",
  "mix.exs",
  "composer.json",
  "Package.swift",
  "pubspec.yaml",
  "pom.xml",
  "build.gradle",
  "build.gradle.kts",
  "build.sbt",
  "CMakeLists.txt",
  "Makefile",
  "justfile",
  "deno.json",
  "deno.jsonc",
  "setup.py",
  "setup.cfg",
  "Pipfile",
  "MODULE.bazel",
  "WORKSPACE",
  "flake.nix",
}

local function with_vim(fake_vim, callback)
  local previous_vim = _G.vim
  _G.vim = fake_vim

  local ok, err = xpcall(callback, debug.traceback)
  _G.vim = previous_vim

  if not ok then
    error(err, 0)
  end
end

test.describe("project root", function()
  test.it("returns the first valid root in strategy order", function()
    local calls = {}
    local strategies = {
      function(bufnr)
        calls[#calls + 1] = { name = "first", bufnr = bufnr }
        return nil
      end,
      function(bufnr)
        calls[#calls + 1] = { name = "second", bufnr = bufnr }
        return "/project"
      end,
      function()
        error("later strategies should not run")
      end,
    }

    test.equal(project_root.resolve(7, strategies), "/project")
    test.equal(#calls, 2)
    test.equal(calls[1].name, "first")
    test.equal(calls[1].bufnr, 7)
    test.equal(calls[2].name, "second")
    test.equal(calls[2].bufnr, 7)
  end)

  test.it("uses the git ancestor before other strategies", function()
    local calls = {}

    with_vim({
      fs = {
        root = function(bufnr, marker)
          calls[#calls + 1] = { name = "git", bufnr = bufnr, marker = marker }
          return "/repository"
        end,
      },
      fn = {
        getcwd = function()
          calls[#calls + 1] = { name = "cwd" }
          return "/working-directory"
        end,
      },
    }, function()
      test.equal(project_root.resolve(3), "/repository")
    end)

    test.equal(#calls, 1)
    test.equal(calls[1].name, "git")
    test.equal(calls[1].bufnr, 3)
    test.equal(calls[1].marker, ".git")
  end)

  test.it("checks non-git markers in declared order", function()
    local markers = {}

    with_vim({
      fs = {
        root = function(_, marker)
          markers[#markers + 1] = marker
          if marker == "flake.nix" then
            return "/flake-project"
          end
        end,
      },
      fn = {
        getcwd = function()
          error("working directory should not be used")
        end,
      },
    }, function()
      test.equal(project_root.resolve(5), "/flake-project")
    end)

    test.equal(#markers, #expected_markers)
    for index, marker in ipairs(expected_markers) do
      test.equal(markers[index], marker)
    end
  end)

  test.it("uses the working directory when no configured marker is found", function()
    local calls = {}

    with_vim({
      fs = {
        root = function(_, marker)
          calls[#calls + 1] = marker
        end,
      },
      fn = {
        getcwd = function()
          calls[#calls + 1] = "cwd"
          return "/working-directory"
        end,
      },
    }, function()
      test.equal(project_root.resolve(5), "/working-directory")
    end)

    test.equal(#calls, #expected_markers + 1)
    for index, marker in ipairs(expected_markers) do
      test.equal(calls[index], marker)
    end
    test.equal(calls[#calls], "cwd")
  end)
end)

test.finish()
