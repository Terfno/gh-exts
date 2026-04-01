#!/bin/sh

manifest_path() {
  printf '%s\n' "${GH_EXTS_MANIFEST:-${XDG_CONFIG_HOME:-$HOME/.config}/gh/extensions.txt}"
}

manifest_dir() {
  dirname "$(manifest_path)"
}

extension_dir() {
  printf '%s\n' "${GH_EXTENSIONS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/gh/extensions}"
}

require_gh() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh-exts: gh command is required" >&2
    exit 1
  fi
}

log_pre() {
  printf '[gh-exts] %s\n' "$*" >&2
}

log_post() {
  printf '[gh-exts] %s\n' "$*" >&2
}

die() {
  printf 'gh-exts: %s\n' "$*" >&2
  exit 1
}

main() {
  require_gh
  dispatch "$@"
}
