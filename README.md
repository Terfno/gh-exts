# gh-exts

`gh-exts` is a GitHub CLI extension that helps you manage installed `gh` extensions
with a manifest file.

Use `gh exts` instead of `gh extension`, `gh extensions`, or `gh ext` when you want your extension state to stay reproducible.

## Getting Started

install:

```sh
gh extension install terfno/gh-exts
```

usage:

```sh
gh exts -h
```
```
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
- Can rebuild your local extension state from the manifest

The manifest file is stored at: `~/.config/gh/extensions.txt`

## Manifest Format

The manifest is a plain text file with one extension per line.

```text
# for terfno/gh-exts

# latest tracking
dlvhdr/gh-dash

# pinned
terfno/gh-wt:69ee2692229d9481b41e3d2a492c9df2af00c593
```

Syn:

- Empty lines are ignored
- Lines starting with `#` are ignored
- `owner/repo` means latest tracking
- `owner/repo:pin` means pinned

## Install

From a local clone:

```sh
chmod +x gh-exts
gh extension install .
```

To reinstall during development:

```sh
gh extension install . --force
```

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

- Pin detection currently relies on `.pin-*` marker files in the installed
  extension directory
- Manifest rewrites currently normalize the file and do not preserve comments
- `upgrade` is not wrapped specially; it is delegated to `gh extension upgrade`

## Development

Useful local checks:

```sh
sh -n gh-exts lib/common.sh lib/manifest.sh lib/state.sh lib/commands.sh
```

To inspect the current help output:

```sh
./gh-exts
```
