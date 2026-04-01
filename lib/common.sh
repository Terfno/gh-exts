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

mktemp_file() {
  mktemp "${TMPDIR:-/tmp}/gh-exts.XXXXXX"
}

cleanup_file() {
  if [ -n "${1:-}" ] && [ -f "$1" ]; then
    rm -f "$1"
  fi
}

repo_name_from_repo() {
  basename "$1"
}

command_name_from_repo() {
  name=$(repo_name_from_repo "$1")
  name=${name#gh-}
  printf 'gh %s\n' "$name"
}

short_name_from_repo() {
  name=$(repo_name_from_repo "$1")
  printf '%s\n' "${name#gh-}"
}

confirm_action() {
  prompt="$1"
  answer=""

  printf '%s [y/N] ' "$prompt" >&2
  read -r answer || true

  case "$answer" in
    y|Y|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
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
