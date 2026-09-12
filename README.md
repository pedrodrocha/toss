# toss.nvim

A tiny Neovim plugin for tossing editor context into an adjacent terminal pane.

## Usage

```lua
require("toss").setup({
  transport = "auto",
  mappings = true,
})
```

Normal mappings toss the current file. Visual mappings toss the selected line
range. The `<leader>tyh/j/k/l` mappings explicitly toss the latest yank context,
including file-originated yank, delete, and change ranges.

## Tests

Run the unit and headless Neovim integration tests with:

```sh
./tests/run.sh
```

The test harness uses the system Lua and Neovim executables by default. Override them when needed:

```sh
LUA_BIN=luajit NVIM_BIN=/path/to/nvim ./tests/run.sh
```

The tests do not require Herdr, Ghostty, network access, or an AI coding agent.

## Development

See [DEVELOPMENT.md](DEVELOPMENT.md) for the working-tree workflow, Neovim commands, Herdr checks, and automated tests.
