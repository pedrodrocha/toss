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

run_unit_tests() {
  local status=0
  local found=0
  local spec

  while IFS= read -r spec; do
    found=1
    printf '  Spec: %s\n' "$spec"
    if ! "$lua_bin" "$spec"; then
      status=1
    fi
  done < <(find tests/unit -maxdepth 1 -type f -name '*_spec.lua' -print | sort)

  if [[ "$found" -eq 0 ]]; then
    printf 'error: no unit test specs found\n' >&2
    return 1
  fi

  return "$status"
}

run_integration_tests() {
  local status=0
  local found=0
  local spec

  while IFS= read -r spec; do
    found=1
    printf '  Spec: %s\n' "$spec"
    if ! "$nvim_bin" --headless -u NONE -i NONE -n -l "$spec"; then
      status=1
    fi
    printf '\n'
  done < <(find tests/integration -maxdepth 1 -type f -name '*_spec.lua' -print | sort)

  if [[ "$found" -eq 0 ]]; then
    printf 'error: no integration test specs found\n' >&2
    return 1
  fi

  return "$status"
}

printf '\n== Unit tests ==\n'
overall_status=0
if ! run_unit_tests; then
  overall_status=1
fi

printf '\n== Integration tests ==\n'
if ! run_integration_tests; then
  overall_status=1
fi

if [[ "$overall_status" -eq 0 ]]; then
  printf 'All tests passed.\n'
else
  printf 'Some tests failed.\n' >&2
fi

exit "$overall_status"
