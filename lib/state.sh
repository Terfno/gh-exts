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

print_manifest_diff_preview() {
  current_file="$1"
  candidate_file="$2"

  diff -u "$current_file" "$candidate_file" 2>/dev/null | while IFS= read -r line; do
    case "$line" in
      ---*|+++*|@@*)
        continue
        ;;
      -*|+*)
        printf '[gh-exts] %s\n' "$line" >&2
        ;;
    esac
  done

}

print_repo_list() {
  manifest_tsv="$1"

  while IFS="$(printf '\t')" read -r ext_repo ext_pin; do
    [ -n "$ext_repo" ] || continue
    if [ -n "$ext_pin" ]; then
      printf '[gh-exts] %s:%s\n' "$ext_repo" "$ext_pin" >&2
    else
      printf '[gh-exts] %s\n' "$ext_repo" >&2
    fi
  done < "$manifest_tsv"
}
