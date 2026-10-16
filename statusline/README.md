# Claude Code Status Line

A 5-line status line for Claude Code showing model, context usage, rate limits, and git info.

```
Opus 5.5 / high
Ctx: 61.6k (6.0%) | $0.17
Session: 0% resets 6:40pm (4h 31m)
Weekly:  44% resets Sun Oct 18 9:00am
⎇ main | ~/Projects/claude-certified-architect
```

- **Line 1**: model and effort level (⚡ when fast mode is on)
- **Line 2**: context tokens used, % of context window, session cost
- **Line 3**: 5-hour session limit usage and reset time
- **Line 4**: weekly limit usage and reset time
- **Line 5**: git branch (`*` if uncommitted changes) and working directory

## Install

> Sharing with someone? Send them [`HANDOFF.md`](./HANDOFF.md).

Requires `jq` (`brew install jq` or `apt install jq`).

From a clone of this repo:

```bash
bash statusline/install.sh
```

Or directly:

```bash
curl -fsSL https://raw.githubusercontent.com/mrta83/claude-certified-architect/main/statusline/install.sh | bash
```

Then restart Claude Code.

The installer writes `~/.claude/statusline-command.sh` and adds a `statusLine` entry to `~/.claude/settings.json`, keeping your other settings. Any existing script or settings file is backed up first with a timestamp suffix.

## Uninstall

Remove the `statusLine` key from `~/.claude/settings.json` (or restore the `.bak` file) and delete `~/.claude/statusline-command.sh`.
