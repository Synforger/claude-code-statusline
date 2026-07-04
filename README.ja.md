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

2. スクリプトに実行権限を付与 (未付与の場合):

```bash
chmod +x statusline.sh
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
            "command": "/path/to/claude-code-statusline/statusline.sh"
          }
        ]
      }
    ]
  }
}
```

`/path/to/` は clone した実際のパスに置き換えてください。

4. Claude Code を再起動すると、ターミナル上部に statusline が表示されます。

## ライセンス

MIT
