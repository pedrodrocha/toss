# Development

Develop directly from this checkout. No installation or package-manager setup is needed.

## Quick start

Open Neovim with its working directory set to the repository, then run:

```vim
:luafile dev/init.lua
```

You should see a notification confirming that the development source was loaded. The setup also selects `transport = "auto"`.

If Neovim's working directory is elsewhere, use the absolute path:

```vim
:luafile /path/to/toss.nvim/dev/init.lua
```

Verify the loaded source when needed:

```vim
:lua print(debug.getinfo(require("toss").setup, "S").source)
```

It should point to this checkout's `lua/toss/init.lua`. If an installed copy was already loaded, `dev/init.lua` clears its cached modules for the current session. Restart Neovim to return to the normal installed setup.

## Try it

Inside Herdr, the development setup automatically selects Herdr. Open a project file and run:

```vim
:edit README.md
:lua require("toss").right()
```

Outside Herdr, use an injected transport for a local check:

```vim
:lua require("toss").setup({ transport = { send = function(direction, text) print(direction .. ": " .. text); return true end } })
:lua require("toss").right()
```

After editing Lua files, run `:luafile dev/init.lua` again to reload the working-tree modules.

## Automated tests

From the repository root:

```sh
./tests/run.sh
```
