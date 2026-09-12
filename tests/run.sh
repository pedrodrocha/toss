#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

lua_bin="${LUA_BIN:-lua}"
nvim_bin="${NVIM_BIN:-nvim}"

if ! command -v "$lua_bin" >/dev/null 2>&1; then
  printf 'error: Lua executable not found: %s\n' "$lua_bin" >&2
  exit 1
fi

if ! command -v "$nvim_bin" >/dev/null 2>&1; then
  printf 'error: Neovim executable not found: %s\n' "$nvim_bin" >&2
  exit 1
fi

printf 'Running unit tests...\n'
"$lua_bin" tests/unit/runner_spec.lua

printf 'Running headless Neovim integration tests...\n'
"$nvim_bin" --headless -u NONE -i NONE -n -l tests/integration/nvim_spec.lua
