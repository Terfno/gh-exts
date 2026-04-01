# gh-exts state

## Current Status

- `SPEC.md` を読了し、`README.md` は無視、`ref/*` は参考扱いとして本実装の前提にしない方針を確認した。
- 実装は shell ベースの GitHub CLI extension として進める。
- `gh-exts` のエントリポイントと補助ライブラリ群を作成し、最初のコミットを完了した。
- manifest 解析、installed state 検出、各 subcommand の spec 準拠動作を実装した。
- mock `gh` による install/remove/list の smoke test を実施した。
- 実環境では `./gh-exts list </dev/null` を実行し、manifest 未生成時の確認プロンプトと pin 表示を確認した。

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
- `list` は installed state から pin を検出して `repo[:pin]` を表示する。
- manifest 同期はコメント保持を行わず、installed state に追従する形で正規化して書き戻す。
- 確認プロンプトは `/dev/tty` ではなく標準入力を使う。

## Implemented Behavior

- `install <repo> [flags]`
- `remove <name> [flags]`
- `upgrade [name] [flags]`
- `list`
- 上記以外の subcommand の `gh extension` への委譲
- manifest の生成、更新、削除反映
- `.pin-*` marker による pin 検出
- no-arg install/remove における確認付き rebuild フロー

## Validation

- `sh -n gh-exts lib/common.sh lib/manifest.sh lib/state.sh lib/commands.sh`
- mock `gh` で install/remove/list を検証
- 実環境 `gh extension list` を使った `./gh-exts list </dev/null` を確認

## Next

- 現在の実装単位をコミットする。
- 追加の仕様差分が見つかったら次の単位で詰める。
