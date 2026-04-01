#!/bin/sh

manifest_exists() {
  [ -f "$(manifest_path)" ]
}

ensure_manifest_dir() {
  mkdir -p "$(manifest_dir)"
}

validate_repo() {
  case "$1" in
    */*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

parse_manifest_line() {
  manifest_line="$1"

  case "$manifest_line" in
    ''|'#'*)
      return 1
      ;;
  esac

  parsed_repo=${manifest_line%%:*}
  if [ "$parsed_repo" != "$manifest_line" ]; then
    parsed_pin=${manifest_line#*:}
  else
    parsed_pin=""
  fi

  if [ -z "$parsed_repo" ] || ! validate_repo "$parsed_repo"; then
    die "invalid manifest entry: $manifest_line"
  fi

  if [ -n "$parsed_pin" ] && [ "$parsed_pin" = "$manifest_line" ]; then
    die "invalid manifest entry: $manifest_line"
  fi

  printf '%s\t%s\n' "$parsed_repo" "$parsed_pin"
}

read_manifest_to_tsv() {
  output="$1"
  : > "$output"

  if ! manifest_exists; then
    return 0
  fi

  while IFS= read -r manifest_line || [ -n "$manifest_line" ]; do
    parsed=$(parse_manifest_line "$manifest_line") || continue
    printf '%s\n' "$parsed" >> "$output"
  done < "$(manifest_path)"
}

write_manifest_from_tsv() {
  input="$1"
  tmpfile=$(mktemp_file)

  while IFS="$(printf '\t')" read -r manifest_repo manifest_pin; do
    [ -n "$manifest_repo" ] || continue
    if [ -n "$manifest_pin" ]; then
      printf '%s:%s\n' "$manifest_repo" "$manifest_pin" >> "$tmpfile"
    else
      printf '%s\n' "$manifest_repo" >> "$tmpfile"
    fi
  done < "$input"

  ensure_manifest_dir
  mv "$tmpfile" "$(manifest_path)"
}

manifest_contains_repo() {
  repo="$1"
  input="$2"
  awk -F '\t' -v repo="$repo" '$1 == repo { found = 1 } END { exit found ? 0 : 1 }' "$input"
}

upsert_manifest_entry() {
  repo="$1"
  pin="$2"
  current="$3"
  output="$4"

  awk -F '\t' -v OFS='\t' -v repo="$repo" -v pin="$pin" '
    $1 == repo {
      if (!seen) {
        print repo, pin
        seen = 1
      }
      next
    }
    { print $1, $2 }
    END {
      if (!seen) {
        print repo, pin
      }
    }
  ' "$current" > "$output"
}

remove_manifest_entry() {
  selector="$1"
  current="$2"
  output="$3"
  : > "$output"

  while IFS="$(printf '\t')" read -r manifest_repo manifest_pin; do
    [ -n "$manifest_repo" ] || continue

    repo_name=$(repo_name_from_repo "$manifest_repo")
    short_name=$(short_name_from_repo "$manifest_repo")

    case "$selector" in
      "$manifest_repo"|"$repo_name"|"$short_name")
        continue
        ;;
    esac

    printf '%s\t%s\n' "$manifest_repo" "$manifest_pin" >> "$output"
  done < "$current"
}
