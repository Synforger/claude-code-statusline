# claude-code-statusline

> 🇬🇧 English: [README.md](README.md)

[Claude Code](https://docs.anthropic.com/en/docs/claude-code) (Max Plan) の rate limit と context 使用量を一目で確認できる statusline スクリプト。

```
[Opus 4.6] 5h:24%(3h22m) 7d:53% ctx:███░░░░░35%
```

## 表示内容

| 区画 | 説明 |
|---------|-------------|
| `[Opus 4.6]` | 現在のモデル名 |
| `5h:24%(3h22m)` | 5 時間 rate limit の使用率 + リセットまでの残り時間 |
| `7d:53%` | 7 日 rate limit の使用率 |
| `ctx:███░░░░░35%` | context window 使用量 (バー + パーセント表示) |

使用率に応じて色が変わります: 緑 (<50%) → 黄 (50-79%) → 赤 (80%+)。

## 必要なもの

- [jq](https://jqlang.github.io/jq/) (JSON プロセッサ)

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq
```

## セットアップ

1. このリポジトリを clone またはダウンロード:

```bash
git clone https://github.com/synforger/claude-code-statusline.git
```

2. スクリプト 2 本に実行権限を付与 (未付与の場合):

```bash
chmod +x src/statusline.sh src/rotate-usage-log.sh
```

3. Claude Code の設定 (`~/.claude/settings.json`) に追加:

```json
{
  "hooks": {
    "StatusLine": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/claude-code-statusline/src/statusline.sh"
          }
        ]
      }
    ]
  }
}
```

`/path/to/` は clone した実際のパスに置き換えてください。

4. Claude Code を再起動すると、ターミナル上部に statusline が表示されます。

## 使用量の記録

rate limit を含む表示の更新ごとに、 `rate-limits.jsonl` へ JSON を 1 行足します (時刻・session・
口座・モデル・5 時間と 7 日の使用率とリセット時刻・token 数・context 使用率)。 口座は
`CLAUDE_CONFIG_DIR` から決まります (`~/.claude-work` は `work`、 未設定と `~/.claude` は
`personal`)。 tmux の中では `tmux-session-map/<tmux session>` に、 そこで動く Claude の session id も
書きます (同じ directory を使うタブを読み手が区別するため)。

置き場は、 環境変数 `AGENT_PLATFORM_ROOT` があれば `$AGENT_PLATFORM_ROOT/state/statusline/`、
無ければ `${XDG_STATE_HOME:-~/.local/state}/claude-code-statusline/` です。

月が変わると `rotate-usage-log.sh` (= `statusline.sh` の隣に置く) が記録を
`rate-limits-<時刻>.jsonl.gz` へ退け、 口座ごとの最新の行だけを持つ新しい記録を始めます (休んでいる
口座の使用率も表示できるように)。 履歴は消しません。

## テスト

```bash
task test:unit
```

作り物の `HOME` で、 器の根あり・なしの両方を走らせ、 置き場の外へ何も書かないことも確かめます。

## ライセンス

MIT
