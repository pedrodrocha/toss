# Development

This repository can be developed directly from its working tree. No plugin installation, copying, symlink, or package-manager configuration is required.

## Load the working tree

Open the repository in Neovim and run this command:

```vim
:luafile dev/init.lua
```

If Neovim's working directory is elsewhere, use the absolute path:

```vim
:luafile /path/to/toss.nvim/dev/init.lua
```

The development file prepends this checkout to Neovim's runtime and Lua package paths, then clears cached `toss` modules. A subsequent `require("toss")` therefore uses the working tree even if an installed copy was loaded earlier.

This only changes the current Neovim process. It does not modify installed files or the normal Neovim configuration. Restart Neovim to return to the normal installed setup.

Verify the loaded source:

```vim
:lua print(vim.fn.has("nvim"))
:lua print(debug.getinfo(require("toss").setup, "S").source)
```

The first command should print `1`. The second should print a path ending in this repository's `lua/toss/init.lua`.

## Exercise the plugin

Open a project file and use an injected transport for a local, external-process-free check:

```vim
:edit README.md
:lua require("toss").setup({ transport = { send = function(direction, text) print(direction .. ": " .. text); return true end } })
:lua require("toss").right()
```

When Neovim is running inside Herdr, the `HERDR_*` environment is preserved, so the real transport can be exercised with:

```vim
:lua require("toss").setup({ transport = "herdr" })
:lua require("toss").right()
```

After editing Lua files, run `:luafile dev/init.lua` again before testing. This clears the cached `toss` modules and loads the latest working-tree code.

## Automated tests

Run the unit and headless Neovim integration tests from the repository root:

```sh
./tests/run.sh
```

The tests do not require Herdr, Ghostty, network access, or an AI coding agent.
