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

extract_install_repo() {
  repo=""
  expect_pin=0
  extracted_pin=""

  for arg in "$@"; do
    if [ "$expect_pin" -eq 1 ]; then
      extracted_pin="$arg"
      expect_pin=0
      continue
    fi

    case "$arg" in
      --pin)
        expect_pin=1
        ;;
      --pin=*)
        extracted_pin=${arg#--pin=}
        ;;
      -*)
        ;;
      *)
        if [ -z "$repo" ]; then
          repo="$arg"
        fi
        ;;
    esac
  done

  printf '%s\t%s\n' "$repo" "$extracted_pin"
}

read_manifest_and_state() {
  MANIFEST_TSV=$(mktemp_file)
  INSTALLED_STATE_TSV=$(mktemp_file)
  INSTALLED_MANIFEST_TSV=$(mktemp_file)
  trap 'cleanup_file "$MANIFEST_TSV"; cleanup_file "$INSTALLED_STATE_TSV"; cleanup_file "$INSTALLED_MANIFEST_TSV"' EXIT HUP INT TERM

  read_manifest_to_tsv "$MANIFEST_TSV"
  installed_state_to_tsv "$INSTALLED_STATE_TSV"
  installed_state_as_manifest_tsv "$INSTALLED_STATE_TSV" "$INSTALLED_MANIFEST_TSV"
}

sync_existing_manifest_if_needed() {
  if ! manifest_exists; then
    return 1
  fi

  read_manifest_to_tsv "$MANIFEST_TSV"
  if sync_manifest_from_installed "$MANIFEST_TSV" "$INSTALLED_MANIFEST_TSV"; then
    log_post "manifest updated to match installed extensions: $(manifest_path)"
    read_manifest_to_tsv "$MANIFEST_TSV"
    return 0
  fi

  return 1
}

generate_manifest_from_installed() {
  if confirm_action "manifest is missing. generate $(manifest_path) from installed extensions?"; then
    write_manifest_from_tsv "$INSTALLED_MANIFEST_TSV"
    log_post "created manifest from installed extensions: $(manifest_path)"
    return 0
  fi

  log_post "manifest generation canceled"
  return 1
}

reinstall_manifest_entries() {
  manifest_tsv="$1"

  while IFS="$(printf '\t')" read -r repo pin; do
    [ -n "$repo" ] || continue
    if [ -n "$pin" ]; then
      gh extension install --force --pin "$pin" "$repo"
    else
      gh extension install --force "$repo"
    fi
  done < "$manifest_tsv"
}

remove_stray_extensions() {
  installed_state="$1"
  manifest_tsv="$2"

  while IFS="$(printf '\t')" read -r _command repo _pin _version; do
    [ -n "$repo" ] || continue
    if ! manifest_contains_repo "$repo" "$manifest_tsv"; then
      gh extension remove "$(short_name_from_repo "$repo")"
    fi
  done < "$installed_state"
}

cmd_install() {
  parsed=$(extract_install_repo "$@")
  repo=$(printf '%s' "$parsed" | awk -F '\t' '{print $1}')
  pin=$(printf '%s' "$parsed" | awk -F '\t' '{print $2}')

  if [ -n "$repo" ]; then
    log_pre "delegating to gh extension install for $repo and updating manifest on success"
    gh extension install "$@"

    current=$(mktemp_file)
    updated=$(mktemp_file)
    trap 'cleanup_file "$current"; cleanup_file "$updated"' EXIT HUP INT TERM
    read_manifest_to_tsv "$current"
    upsert_manifest_entry "$repo" "$pin" "$current" "$updated"
    write_manifest_from_tsv "$updated"
    log_post "installed $repo and updated manifest: $(manifest_path)"
    return 0
  fi

  if ! manifest_exists; then
    log_pre "manifest is missing, delegating to gh extension install"
    exec gh extension install "$@"
  fi

  read_manifest_and_state
  log_pre "rebuilding installed extensions from manifest after syncing installed state"
  sync_existing_manifest_if_needed || log_post "manifest already matches installed extensions"
  if ! confirm_action "reinstall extensions listed in $(manifest_path)?"; then
    die "rebuild canceled"
  fi
  reinstall_manifest_entries "$MANIFEST_TSV"
  log_post "rebuild complete from manifest: $(manifest_path)"
}

cmd_remove() {
  target="${1:-}"

  if [ -n "$target" ]; then
    log_pre "delegating to gh extension remove for $target and updating manifest on success"
    gh extension remove "$@"

    current=$(mktemp_file)
    updated=$(mktemp_file)
    trap 'cleanup_file "$current"; cleanup_file "$updated"' EXIT HUP INT TERM
    read_manifest_to_tsv "$current"
    remove_manifest_entry "$target" "$current" "$updated"
    write_manifest_from_tsv "$updated"
    log_post "removed $target and updated manifest: $(manifest_path)"
    return 0
  fi

  if ! manifest_exists; then
    log_pre "manifest is missing, delegating to gh extension remove"
    exec gh extension remove "$@"
  fi

  read_manifest_and_state
  log_pre "removing extensions not present in manifest, then reinstalling manifest entries"
  if ! confirm_action "remove stray extensions and rebuild from $(manifest_path)?"; then
    die "rebuild canceled"
  fi
  remove_stray_extensions "$INSTALLED_STATE_TSV" "$MANIFEST_TSV"
  reinstall_manifest_entries "$MANIFEST_TSV"
  log_post "removed stray extensions and rebuilt manifest entries"
}

cmd_upgrade() {
  if [ $# -gt 0 ]; then
    log_pre "delegating to gh extension upgrade for $1 without changing manifest by default"
  else
    log_pre "delegating to gh extension upgrade --all semantics without changing manifest by default"
  fi
  gh extension upgrade "$@"
  log_post "upgrade finished; manifest left unchanged"
}

cmd_list() {
  read_manifest_and_state
  log_pre "comparing manifest with installed extensions and syncing if needed"

  if manifest_exists; then
    if sync_existing_manifest_if_needed; then
      :
    else
      log_post "manifest already matches installed extensions"
    fi
  else
    generate_manifest_from_installed || true
  fi

  print_manifest_aware_list "$INSTALLED_STATE_TSV"
}

cmd_help() {
  log_pre "delegating to gh extension"
  exec gh extension
}

cmd_delegate() {
  log_pre "delegating to gh extension $*"
  exec gh extension "$@"
}
