# claude-code-statusline

A statusline script for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (Max Plan) that displays rate limits and context usage at a glance.

```
[Opus 4.6] 5h:24%(3h22m) 7d:53% ctx:███░░░░░35%
```

## What it shows

| Section | Description |
|---------|-------------|
| `[Opus 4.6]` | Current model name |
| `5h:24%(3h22m)` | 5-hour rate limit usage + time until reset |
| `7d:53%` | 7-day rate limit usage |
| `ctx:███░░░░░35%` | Context window usage (visual bar + percentage) |

Colors change based on usage: green (<50%) → yellow (50-79%) → red (80%+).

## Requirements

- [jq](https://jqlang.github.io/jq/) (JSON processor)

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq
```

## Setup

1. Clone or download this repository:

```bash
git clone https://github.com/synforger/claude-code-statusline.git
```

2. Make the script executable (if not already):

```bash
chmod +x statusline.sh
```

3. Add to your Claude Code settings (`~/.claude/settings.json`):

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

Replace `/path/to/` with the actual path to the cloned repository.

4. Restart Claude Code. The statusline should appear at the top of your terminal.

## License

MIT
