# toss.nvim

[![Latest release](https://img.shields.io/github/v/release/pedrodrocha/toss?sort=semver)](https://github.com/pedrodrocha/toss/releases)
[![Neovim 0.10+](https://img.shields.io/badge/Neovim-0.10%2B-57A143?logo=neovim&logoColor=white)](https://neovim.io/)

`toss.nvim` sends file and selection references from Neovim to an adjacent
terminal pane, where a coding agent can use them as context.

The mental model is:

```text
choose context with Vim → choose a direction → send a text reference
```

## Installation and setup

Install `pedrodrocha/toss.nvim` with your plugin manager. For example, with
[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "pedrodrocha/toss.nvim",
  config = function()
    require("toss").setup({
      transport = "auto",
      mappings = true,
    })
  end,
}
```

`mappings = true` opts into toss's default keymaps. Leave mappings unset
to use only the Lua API, or pass a mapping table to customize or disable
individual entries.

## Requirements

- Neovim 0.10 or newer.
- Herdr, which is currently the only production transport.
- Neovim running inside a Herdr pane, with `herdr` on `$PATH` and Herdr's
  `HERDR_ENV=1` and `HERDR_PANE_ID` environment variables available.

See [Transport](#transport) for details and planned alternatives.

## Context and payloads

In Normal mode, toss sends the whole current file. It does not include the
cursor line:

```text
@src/domain/user.lua
```

In Visual mode, toss sends the inclusive line envelope of the active
selection:

```text
@src/domain/user.lua#L42-L67
```

Characterwise, linewise, and blockwise selections are supported. Columns are
ignored and reverse selections are normalized to ascending line numbers.

File paths are project-relative when a project root can be detected. An
absolute path is used when a relative path cannot be produced. Unnamed and
special buffers are rejected with a `toss:` notification.

## API

The public directional API is:

```lua
local toss = require("toss")

toss.left()
toss.down()
toss.up()
toss.right()
```

Call a direction while a Visual selection is active to toss that selection;
otherwise the current file is tossed.

The transport receives the reference as text. Sending does **not** append a
newline, press Enter, or submit the text.

## Mappings

When enabled, the default file mappings are installed in Normal and Visual
mode:

| Mapping | Direction |
| --- | --- |
| `<leader>th` | left |
| `<leader>tj` | down |
| `<leader>tk` | up |
| `<leader>tl` | right |

The mappings use `x` mode for Visual operations, so the active selection is
captured before Visual mode ends.

The enabled default set also includes explicit latest-yank mappings:

| Mapping | Direction |
| --- | --- |
| `<leader>tyh` | left |
| `<leader>tyj` | down |
| `<leader>tyk` | up |
| `<leader>tyl` | right |

These use the latest unnamed-register yank, delete, or change. When Neovim
can identify its file range, it becomes a ranged file reference; otherwise the
register text is sent literally.

Mappings can be overridden or disabled individually. Omitted entries keep
their defaults:

```lua
require("toss").setup({
  transport = "auto",
  mappings = {
    left = "<leader>th",
    down = "<leader>tj",
    up = false,
    right = "<leader>tl",
    yank_left = false,
  },
})
```

Set `mappings = false` to remove toss's mappings.

## Transport

A transport is the delivery adapter between `toss.nvim` and the pane system
around Neovim. The core plugin only captures context and formats a text
reference. The transport receives that reference plus a direction, then uses
its own pane model to find the adjacent destination and send the text there.

A transport is responsible for:

- deciding whether it is available in the current session;
- resolving `left`, `down`, `up`, or `right` to a destination pane;
- sending the exact payload text without adding a newline, pressing Enter, or
  submitting it;
- focusing the target pane after a successful toss;
- reporting unavailable panes, commands, or environments as friendly `toss:`
  notifications.

### Herdr

Herdr is the only production transport today. To use it, run Neovim inside a
Herdr pane with `herdr` on `$PATH` and Herdr's environment variables available
(`HERDR_ENV=1` and `HERDR_PANE_ID`).

Use `transport = "herdr"` to select it directly. With `transport = "auto"`,
toss selects Herdr when that environment is available.

### Expanding transport support

More transports are planned. A new transport is a registered Lua module that
implements `available()`, `send(direction, text)`, and `focus(direction)`.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines and
[DEVELOPMENT.md](DEVELOPMENT.md) for local setup, workflows, and test commands.

## License

[MIT](LICENSE)
