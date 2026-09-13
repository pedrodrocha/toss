# toss.nvim

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

`toss.nvim` does not create mappings by default. Set `mappings = true` to use
the defaults, or provide a mapping table to customize them. `which_key = true`
optionally registers the `<leader>t` group when which-key is installed.

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

The initial transport is Herdr. For the setup above to work:

- use a recent Neovim; Neovim 0.10+ is required, and the project currently
  tests Neovim 0.12.5;
- run Neovim inside a Herdr pane, normally through Ghostty;
- have the `herdr` executable available on `$PATH`;
- preserve Herdr's `HERDR_ENV=1` and `HERDR_PANE_ID` environment variables.

With `transport = "auto"`, toss selects the available transport (currently
Herdr) when that environment is available. This is transport detection, not
agent detection. You can select Herdr explicitly with `transport = "herdr"`.
Herdr resolves the neighbor in the requested direction and receives the text
without submitting it. A missing environment, executable, or adjacent pane
produces a friendly `toss:` notification.

## Tests

Run the unit and headless Neovim integration tests with:

```sh
./tests/run.sh
```

The tests do not require Herdr, Ghostty, network access, or an AI coding
agent. See [DEVELOPMENT.md](DEVELOPMENT.md) for local development commands.

## License

[MIT](LICENSE)
