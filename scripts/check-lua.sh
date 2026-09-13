#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
requested_lua_ls="${LUA_LS_BIN:-lua-language-server}"
lua_ls_bin="$requested_lua_ls"

if [[ -z "${LUA_LS_BIN:-}" ]]; then
  lua_ls_bin="$(command -v lua-language-server || true)"

  if [[ -z "$lua_ls_bin" ]]; then
    mason_data_home="${XDG_DATA_HOME:-${HOME:-$root_dir}/.local/share}"
    mason_package_dir="$mason_data_home/nvim/mason/packages/lua-language-server"
    for candidate in \
      "$mason_package_dir/lua-language-server" \
      "$mason_package_dir/bin/lua-language-server" \
      "$mason_package_dir/libexec/bin/lua-language-server"; do
      if [[ -x "$candidate" ]]; then
        lua_ls_bin="$candidate"
        break
      fi
    done
  fi
fi

if [[ -z "$lua_ls_bin" ]] || ! command -v "$lua_ls_bin" >/dev/null 2>&1; then
  printf 'error: LuaLS executable not found: %s\n' "$requested_lua_ls" >&2
  printf 'Set LUA_LS_BIN to the path of lua-language-server.\n' >&2
  exit 1
fi

exec "$lua_ls_bin" \
  --check="$root_dir" \
  --checklevel=Warning \
  --configpath="$root_dir/.luarc.json"
