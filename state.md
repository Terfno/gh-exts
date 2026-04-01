# gh-exts state

## Current Status

- `SPEC.md` を読了し、`README.md` は無視、`ref/*` は参考扱いとして本実装の前提にしない方針を確認した。
- 実装は shell ベースの GitHub CLI extension として進める。
- まず `gh-exts` のエントリポイントと補助ライブラリ群を新規作成する。

## Confirmed Spec

- コマンド名は `gh exts`、repository 名は `gh-exts`。
- source of truth は `~/.config/gh/extensions.txt`。
- manifest 行形式は `owner/repo[:pin]`。空行と `#` コメントは無視。
- `install/remove/upgrade/list` は manifest-aware に実装する。
- それ以外の subcommand は `gh extension` に委譲する。
- 実行前後に簡潔な要約メッセージを出す。
- `install/remove/list` の一部フローでは確認プロンプトが必要。

## Implementation Notes

- 既存 tracked file は存在しないため、新規ファイルのみで実装する。
- コミットは新規作成ファイルのみを含める。
- 途中停止に備え、この `state.md` を更新しながら進める。

## Next

- `gh-exts` エントリポイントを作る。
- manifest 解析と `gh extension` 委譲の共通処理をライブラリ化する。
