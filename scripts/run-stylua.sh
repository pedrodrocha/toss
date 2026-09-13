#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
requested_stylua="${STYLUA_BIN:-stylua}"
stylua_bin="$requested_stylua"

if [[ -z "${STYLUA_BIN:-}" ]]; then
  stylua_bin="$(command -v stylua || true)"

  if [[ -z "$stylua_bin" ]]; then
    mason_data_home="${XDG_DATA_HOME:-${HOME:-$root_dir}/.local/share}"
    mason_package_dir="$mason_data_home/nvim/mason/packages/stylua"
    for candidate in \
      "$mason_package_dir/stylua" \
      "$mason_package_dir/bin/stylua" \
      "$mason_package_dir/libexec/bin/stylua"; do
      if [[ -x "$candidate" ]]; then
        stylua_bin="$candidate"
        break
      fi
    done
  fi
fi

if [[ -z "$stylua_bin" ]] || ! command -v "$stylua_bin" >/dev/null 2>&1; then
  printf 'error: StyLua executable not found: %s\n' "$requested_stylua" >&2
  printf 'Set STYLUA_BIN to the path of stylua.\n' >&2
  exit 1
fi

exec "$stylua_bin" "$@"
