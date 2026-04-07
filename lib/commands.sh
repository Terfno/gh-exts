#!/bin/sh

dispatch() {
  subcommand="${1:-}"

  case "$subcommand" in
    -h|--help|help)
      cmd_help
      ;;
    install)
      shift || true
      cmd_install "$@"
      ;;
    remove)
      shift || true
      cmd_remove "$@"
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

apply_manifest_update() {
  target_tsv="$1"
  preview_label="$2"
  confirm_prompt="$3"
  success_label="$4"
  current_file=$(mktemp_file)
  candidate_file=$(mktemp_file)
  emitted_file=$(mktemp_file)

  trap 'cleanup_file "$current_file"; cleanup_file "$candidate_file"; cleanup_file "$emitted_file"' EXIT HUP INT TERM

  if manifest_exists; then
    cp "$(manifest_path)" "$current_file"
  else
    : > "$current_file"
  fi

  render_manifest_candidate "$target_tsv" "$candidate_file" "$emitted_file"

  if cmp -s "$current_file" "$candidate_file"; then
    return 1
  fi

  log_pre "$preview_label"
  print_manifest_diff_preview "$current_file" "$candidate_file"

  if ! confirm_action "$confirm_prompt"; then
    return 1
  fi

  ensure_manifest_dir
  mv "$candidate_file" "$(manifest_path)"
  log_post "$success_label"
  return 0
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
  parse_confirmation_flags "$@"
  trap 'cleanup_file "$PARSED_ARGS_FILE"' EXIT HUP INT TERM
  set --
  while IFS= read -r arg; do
    set -- "$@" "$arg"
  done < "$PARSED_ARGS_FILE"

  parsed=$(extract_install_repo "$@")
  repo=$(printf '%s' "$parsed" | awk -F '\t' '{print $1}')
  pin=$(printf '%s' "$parsed" | awk -F '\t' '{print $2}')

  if [ -n "$repo" ]; then
    log_pre "install $repo"
    gh extension install "$@"

    current=$(mktemp_file)
    updated=$(mktemp_file)
    trap 'cleanup_file "$current"; cleanup_file "$updated"' EXIT HUP INT TERM
    read_manifest_to_tsv "$current"
    upsert_manifest_entry "$repo" "$pin" "$current" "$updated"
    apply_manifest_update "$updated" "manifest update preview" "update manifest?" "manifest updated" || true
    return 0
  fi

  if ! manifest_exists; then
    log_pre "install"
    exec gh extension install "$@"
  fi

  read_manifest_and_state
  log_pre "reinstall from manifest"
  print_repo_list "$MANIFEST_TSV"
  if ! confirm_action "reinstall these extensions?"; then
    die "rebuild canceled"
  fi
  reinstall_manifest_entries "$MANIFEST_TSV"
  log_post "reinstall complete"
}

cmd_remove() {
  parse_confirmation_flags "$@"
  trap 'cleanup_file "$PARSED_ARGS_FILE"' EXIT HUP INT TERM
  set --
  while IFS= read -r arg; do
    set -- "$@" "$arg"
  done < "$PARSED_ARGS_FILE"

  target="${1:-}"

  if [ -n "$target" ]; then
    log_pre "remove $target"
    gh extension remove "$@"

    current=$(mktemp_file)
    updated=$(mktemp_file)
    trap 'cleanup_file "$current"; cleanup_file "$updated"' EXIT HUP INT TERM
    read_manifest_to_tsv "$current"
    remove_manifest_entry "$target" "$current" "$updated"
    apply_manifest_update "$updated" "manifest update preview" "update manifest?" "manifest updated" || true
    return 0
  fi

  if ! manifest_exists; then
    log_pre "remove"
    exec gh extension remove "$@"
  fi

  read_manifest_and_state
  log_pre "remove stray, then reinstall"
  if ! confirm_action "remove stray extensions and reinstall manifest entries?"; then
    die "rebuild canceled"
  fi
  remove_stray_extensions "$INSTALLED_STATE_TSV" "$MANIFEST_TSV"
  reinstall_manifest_entries "$MANIFEST_TSV"
  log_post "reinstall complete"
}

cmd_list() {
  parse_confirmation_flags "$@"
  trap 'cleanup_file "$PARSED_ARGS_FILE"' EXIT HUP INT TERM
  set --
  while IFS= read -r arg; do
    set -- "$@" "$arg"
  done < "$PARSED_ARGS_FILE"

  read_manifest_and_state
  log_pre "list and sync manifest if needed"

  if manifest_exists; then
    apply_manifest_update "$INSTALLED_MANIFEST_TSV" "manifest update preview" "update manifest?" "manifest updated" || true
  else
    apply_manifest_update "$INSTALLED_MANIFEST_TSV" "manifest create preview" "create manifest from installed extensions?" "manifest created" || true
  fi

  gh extension list "$@"
}

cmd_help() {
  printf 'Manage GitHub CLI extensions with manifest sync.\n\n'
  printf 'USAGE\n'
  printf '  gh exts <command> [flags]\n\n'
  printf 'AVAILABLE COMMANDS\n'
  printf '  install:       Install an extension or reinstall from manifest\n'
  printf '  remove:        Remove an extension or remove stray extensions\n'
  printf '  list:          List installed extensions and sync manifest if needed\n\n'
  printf 'FLAGS\n'
  printf '  -y, --yes, --non-interactive\n'
  printf '                 Skip gh-exts confirmation prompts\n\n'
  printf 'LEARN MORE\n'
  printf '  Other subcommands are delegated to `gh extension`.\n'
  printf '  Use `gh exts` instead of `gh extension`, `gh extensions`, or `gh ext`\n'
  printf '  to keep the manifest in sync.\n'
}

cmd_delegate() {
  log_pre "gh extension $*"
  exec gh extension "$@"
}
