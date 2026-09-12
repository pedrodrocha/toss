local M = {}

local function marker_ancestor(marker)
  return function(bufnr)
    return vim.fs.root(bufnr, marker)
  end
end

local function current_working_directory()
  return vim.fn.getcwd()
end

M.strategies = {
  marker_ancestor(".git"),
  marker_ancestor(".hg"),
  marker_ancestor(".svn"),
  marker_ancestor("package.json"),
  marker_ancestor("Cargo.toml"),
  marker_ancestor("pyproject.toml"),
  marker_ancestor("go.work"),
  marker_ancestor("go.mod"),
  marker_ancestor("Gemfile"),
  marker_ancestor("mix.exs"),
  marker_ancestor("composer.json"),
  marker_ancestor("Package.swift"),
  marker_ancestor("pubspec.yaml"),
  marker_ancestor("pom.xml"),
  marker_ancestor("build.gradle"),
  marker_ancestor("build.gradle.kts"),
  marker_ancestor("build.sbt"),
  marker_ancestor("CMakeLists.txt"),
  marker_ancestor("Makefile"),
  marker_ancestor("justfile"),
  marker_ancestor("deno.json"),
  marker_ancestor("deno.jsonc"),
  marker_ancestor("setup.py"),
  marker_ancestor("setup.cfg"),
  marker_ancestor("Pipfile"),
  marker_ancestor("MODULE.bazel"),
  marker_ancestor("WORKSPACE"),
  marker_ancestor("flake.nix"),
  current_working_directory,
}

local function valid_root(root)
  return type(root) == "string" and root ~= ""
end

function M.resolve(bufnr, strategies)
  bufnr = bufnr or 0
  strategies = strategies or M.strategies

  for _, strategy in ipairs(strategies) do
    local root = strategy(bufnr)
    if valid_root(root) then
      return root
    end
  end

  return nil
end

return M
