# claude-code-statusline

> 🇯🇵 日本語版: [README.ja.md](README.ja.md)

A statusline script — `statusline.sh`, a dependency-light bash script — for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (Max Plan) that displays rate limits and context usage at a glance.

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

2. Make the scripts executable (if not already):

```bash
chmod +x statusline.sh rotate-usage-log.sh
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

## Usage log

Each refresh that carries rate limits also appends one JSON line to `rate-limits.jsonl`: time,
session, account, model, the 5-hour and 7-day usage with their reset times, token counts and
context usage. The account comes from `CLAUDE_CONFIG_DIR` (`~/.claude-work` is `work`; unset or
`~/.claude` is `personal`). Inside tmux, the file `tmux-session-map/<tmux session>` also holds
the Claude session id running there, so a reader can tell tabs that share a directory apart.

The files live in `$AGENT_PLATFORM_ROOT/state/statusline/` when `AGENT_PLATFORM_ROOT` is set,
and in `${XDG_STATE_HOME:-~/.local/state}/claude-code-statusline/` otherwise.

When the month changes, `rotate-usage-log.sh` (keep it beside `statusline.sh`) moves the log to
`rate-limits-<time>.jsonl.gz` and starts a new one holding the latest line of each account, so
a resting account still shows its usage. History is kept, never deleted.

## Test

```bash
task test:unit
```

The tests run the scripts on a made-up `HOME`, with and without a platform root, and check that
nothing outside the state folder is written.

## License

MIT
