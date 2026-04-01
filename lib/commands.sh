#!/bin/sh

dispatch() {
  subcommand="${1:-}"

  case "$subcommand" in
    install)
      shift || true
      cmd_install "$@"
      ;;
    remove)
      shift || true
      cmd_remove "$@"
      ;;
    upgrade)
      shift || true
      cmd_upgrade "$@"
      ;;
    list)
      shift || true
      cmd_list "$@"
      ;;
    "")
      cmd_help
      ;;
    *)
      cmd_delegate "$@"
      ;;
  esac
}

cmd_install() {
  die "install is not implemented yet"
}

cmd_remove() {
  die "remove is not implemented yet"
}

cmd_upgrade() {
  die "upgrade is not implemented yet"
}

cmd_list() {
  die "list is not implemented yet"
}

cmd_help() {
  log_pre "delegating to gh extension"
  exec gh extension
}

cmd_delegate() {
  log_pre "delegating to gh extension $*"
  exec gh extension "$@"
}
