#!/bin/sh

pin_for_repo() {
  target_repo="$1"
  ext_dir="$(extension_dir)/$(repo_name_from_repo "$target_repo")"

  if [ ! -d "$ext_dir" ]; then
    return 1
  fi

  pin_file=$(find "$ext_dir" -maxdepth 1 -type f -name '.pin-*' | head -n 1)
  if [ -n "${pin_file:-}" ]; then
    detected_pin=${pin_file##*/.pin-}
    printf '%s\n' "$detected_pin"
    return 0
  fi

  return 1
}

installed_state_to_tsv() {
  output="$1"
  : > "$output"

  gh extension list | while IFS="$(printf '\t')" read -r ext_command ext_repo ext_version _rest; do
    [ -n "$ext_repo" ] || continue
    ext_pin=""
    if detected_pin=$(pin_for_repo "$ext_repo" 2>/dev/null); then
      ext_pin="$detected_pin"
    fi
    printf '%s\t%s\t%s\t%s\n' "$ext_command" "$ext_repo" "$ext_pin" "$ext_version"
  done > "$output"
}

installed_state_as_manifest_tsv() {
  state_file="$1"
  output="$2"

  awk -F '\t' -v OFS='\t' '
    $2 != "" { print $2, $3 }
  ' "$state_file" > "$output"
}

manifest_differs_from_installed() {
  manifest_tsv="$1"
  installed_manifest_tsv="$2"
  ! cmp -s "$manifest_tsv" "$installed_manifest_tsv"
}

sync_manifest_from_installed() {
  manifest_tsv="$1"
  installed_manifest_tsv="$2"

  if manifest_differs_from_installed "$manifest_tsv" "$installed_manifest_tsv"; then
    write_manifest_from_tsv "$installed_manifest_tsv"
    return 0
  fi

  return 1
}

print_manifest_aware_list() {
  state_file="$1"

  while IFS="$(printf '\t')" read -r ext_command ext_repo ext_pin ext_version; do
    [ -n "$ext_repo" ] || continue
    entry="$ext_repo"
    if [ -n "$ext_pin" ]; then
      entry="$ext_repo:$ext_pin"
    fi
    printf '%s\t%s\t%s\n' "$ext_command" "$entry" "$ext_version"
  done < "$state_file"
}
