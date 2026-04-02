# gh-exts

`gh-exts` is a GitHub CLI extension for managing `gh` extensions with a manifest.

Use `gh exts` instead of `gh extension`, `gh extensions`, or `gh ext` when you want
your installed extensions to stay reproducible.

## Getting Started

Install:

```sh
gh extension install terfno/gh-exts
```

usage:

```sh
gh exts -h
```

```text
Manage GitHub CLI extensions with manifest sync.

USAGE
  gh exts <command> [flags]

AVAILABLE COMMANDS
  install:       Install an extension or reinstall from manifest
  remove:        Remove an extension or remove stray extensions
  list:          List installed extensions and sync manifest if needed

LEARN MORE
  Other subcommands are delegated to `gh extension`.
  Use `gh exts` instead of `gh extension`, `gh extensions`, or `gh ext`
  to keep the manifest in sync.
```

## What It Does

- Wraps `gh extension`
- Keeps a manifest of installed extensions
- Supports pinned entries as `owner/repo:pin`
- Can rebuild local extension state from the manifest

The manifest file is stored at:

```text
~/.config/gh/extensions.txt
```

This also works if `~/.config/gh/extensions.txt` is a symbolic link managed from
your dotfiles, as long as the link target is writable.

## Manifest Format

The manifest is a plain text file with one extension per line.

```text
# for terfno/gh-exts

# latest tracking
dlvhdr/gh-dash

# pinned
terfno/gh-wt:69ee2692229d9481b41e3d2a492c9df2af00c593
```

Rules:

- Empty lines are ignored
- Lines starting with `#` are ignored
- `owner/repo` means latest tracking
- `owner/repo:pin` means pinned

## Usage

```text
gh exts install <repo> [flags]
gh exts install

gh exts remove <name> [flags]
gh exts remove

gh exts list
```

Other subcommands are delegated to `gh extension`.

## Behavior

### `gh exts install <repo>`

- Runs `gh extension install`
- Previews the manifest update
- Updates the manifest after confirmation

### `gh exts install`

- Treats the manifest as the source of truth
- Shows the extensions that will be reinstalled
- Reinstalls manifest entries after confirmation

### `gh exts remove <name>`

- Runs `gh extension remove`
- Previews the manifest update
- Updates the manifest after confirmation

### `gh exts remove`

- Removes installed extensions that are not in the manifest
- Reinstalls the manifest entries
- Asks for confirmation before running

### `gh exts list`

- Runs `gh extension list`
- Detects manifest drift
- Shows a simple diff preview before manifest changes
- Updates the manifest only after confirmation

## Notes

- Pin detection currently relies on `.pin-*` marker files in the installed extension directory
- Manifest updates preserve existing comments and blank lines where possible

## Development

Useful local checks:

```sh
sh -n gh-exts lib/common.sh lib/manifest.sh lib/state.sh lib/commands.sh
```

To inspect the current help output:

```sh
./gh-exts
```
