# Status Line Handoff

A custom 5-line status line for Claude Code. It shows model and effort, context usage and cost, session and weekly rate limits, and git branch and directory.

## 1. Install jq (if you don't have it)

```bash
# macOS
brew install jq

# Debian / Ubuntu
sudo apt install jq
```

## 2. Install the status line

```bash
curl -fsSL https://raw.githubusercontent.com/mrta83/claude-certified-architect/main/statusline/install.sh | bash
```

## 3. Restart Claude Code

Quit and reopen Claude Code, or start a new session. The status line appears under the prompt.

## What the installer changes

- Writes `~/.claude/statusline-command.sh`
- Adds a `statusLine` entry to `~/.claude/settings.json` and leaves your other settings alone
- Backs up any existing script or settings file first, as `<file>.bak.<timestamp>`

To undo it, restore the `.bak` file, or remove the `statusLine` key from `~/.claude/settings.json`.

## Troubleshooting

- **Nothing shows up**: run `jq --version` to check jq is installed, then restart Claude Code.
- **Session/Weekly show `-`**: Claude Code didn't send any rate-limit data. This is expected if you sign in with an API key instead of a Claude subscription.
- **Branch shows `no git`**: the current directory isn't a git repository.
