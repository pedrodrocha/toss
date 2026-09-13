# Development

Work directly from this checkout; no installation is needed.

## Quick start

Open Neovim with its working directory set to the repository, then run:

```vim
:luafile dev/init.lua
```

A notification confirms that the checkout was loaded. This setup enables the
mappings and Herdr support; which-key integration is optional.

If Neovim's working directory is elsewhere, use the absolute path:

```vim
:luafile /path/to/toss.nvim/dev/init.lua
```

Verify the loaded source when needed:

```vim
:lua print(debug.getinfo(require("toss").setup, "S").source)
```

It should point to this checkout's `lua/toss/init.lua`. Restart Neovim to
return to the normal installed setup.

## Try it

Inside Herdr, open a project file and run:

```vim
:edit README.md
:lua require("toss").right()
```

If which-key is installed, the `<leader>t` group is labeled `󰧑 toss`.

Outside Herdr, use this temporary local setup:

```vim
:lua local result = require("toss.result"); require("toss").setup({ transport = { send = function(direction, text) print(direction .. ": " .. text); return result.ok() end, focus = function() return result.ok() end, available = function() return true end } })
:lua require("toss").right()
```

After editing Lua files, run `:luafile dev/init.lua` again to reload the development setup.

## Checks

From the repository root, run the test suite with:

```sh
./tests/run.sh
```

Run LuaLS static analysis over `lua/` and `tests/` with:

```sh
./scripts/check-lua.sh
```

The analyzer command defaults to `lua-language-server` and also checks the
standard Neovim Mason installation. Override it for another local installation
with `LUA_LS_BIN=/path/to/lua-language-server ./scripts/check-lua.sh`.
The checked-in `.luarc.json` configures LuaJIT, Neovim's Lua runtime, the
repository's Lua module paths, and the `vim` global.

The root `Makefile` provides these shortcuts:

```sh
make test          # tests
make lint          # LuaLS analysis
make format        # format Lua files
make format-check  # check formatting
make check         # run test, analysis, and format checks
```

Set `LUA_LS_BIN` or `STYLUA_BIN` to use a custom tool installation.

Pull requests run the tests and LuaLS analysis in GitHub Actions. The workflow
uses pinned Neovim and LuaLS releases and does not require Herdr.
