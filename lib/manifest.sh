#!/bin/sh

manifest_exists() {
  [ -f "$(manifest_path)" ]
}

manifest_header() {
  printf '# for terfno/gh-exts\n'
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

  manifest_header >> "$tmpfile"

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

write_manifest_preview_from_tsv() {
  input="$1"
  output="$2"
  : > "$output"

  manifest_header >> "$output"

  while IFS="$(printf '\t')" read -r manifest_repo manifest_pin; do
    [ -n "$manifest_repo" ] || continue
    if [ -n "$manifest_pin" ]; then
      printf '%s:%s\n' "$manifest_repo" "$manifest_pin" >> "$output"
    else
      printf '%s\n' "$manifest_repo" >> "$output"
    fi
  done < "$input"
}

format_manifest_entry() {
  manifest_repo="$1"
  manifest_pin="$2"

  if [ -n "$manifest_pin" ]; then
    printf '%s:%s\n' "$manifest_repo" "$manifest_pin"
  else
    printf '%s\n' "$manifest_repo"
  fi
}

target_pin_for_repo() {
  repo="$1"
  input="$2"

  awk -F '\t' -v repo="$repo" '$1 == repo { print $2; exit }' "$input"
}

append_manifest_entry_if_missing() {
  repo="$1"
  pin="$2"
  output="$3"

  format_manifest_entry "$repo" "$pin" >> "$output"
}

render_manifest_candidate() {
  target_tsv="$1"
  output="$2"
  emitted="$3"

  : > "$output"
  : > "$emitted"

  if ! manifest_exists; then
    write_manifest_preview_from_tsv "$target_tsv" "$output"
    return 0
  fi

  body=$(mktemp_file)
  : > "$body"
  header_seen=0

  while IFS= read -r manifest_line || [ -n "$manifest_line" ]; do
    case "$manifest_line" in
      '# for terfno/gh-exts')
        header_seen=1
        printf '%s\n' "$manifest_line" >> "$body"
        ;;
      ''|'#'*)
        printf '%s\n' "$manifest_line" >> "$body"
        ;;
      *)
        parsed=$(parse_manifest_line "$manifest_line")
        manifest_repo=${parsed%%$(printf '\t')*}
        manifest_pin=${parsed#*$(printf '\t')}

        if manifest_contains_repo "$manifest_repo" "$target_tsv"; then
          if ! manifest_contains_repo "$manifest_repo" "$emitted"; then
            target_pin=$(target_pin_for_repo "$manifest_repo" "$target_tsv")
            format_manifest_entry "$manifest_repo" "$target_pin" >> "$body"
            printf '%s\t%s\n' "$manifest_repo" "$target_pin" >> "$emitted"
          fi
        fi
        ;;
    esac
  done < "$(manifest_path)"

  if [ "$header_seen" -eq 0 ]; then
    manifest_header >> "$output"
  fi
  cat "$body" >> "$output"
  cleanup_file "$body"

  while IFS="$(printf '\t')" read -r manifest_repo manifest_pin; do
    [ -n "$manifest_repo" ] || continue
    if ! manifest_contains_repo "$manifest_repo" "$emitted"; then
      append_manifest_entry_if_missing "$manifest_repo" "$manifest_pin" "$output"
      printf '%s\t%s\n' "$manifest_repo" "$manifest_pin" >> "$emitted"
    fi
  done < "$target_tsv"
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
