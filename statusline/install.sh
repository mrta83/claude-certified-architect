#!/usr/bin/env bash
# Installs a 5-line Claude Code status line:
#   model / effort · context + cost · session limit · weekly limit · git branch + cwd
# Usage: bash statusline/install.sh
#    or: curl -fsSL https://raw.githubusercontent.com/mrta83/claude-certified-architect/main/statusline/install.sh | bash
# Requires: jq, git (optional, for branch display)
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SCRIPT="$CLAUDE_DIR/statusline-command.sh"
SETTINGS="$CLAUDE_DIR/settings.json"

command -v jq >/dev/null || { echo "Error: jq is required (brew install jq / apt install jq)" >&2; exit 1; }
mkdir -p "$CLAUDE_DIR"

# Back up anything we're about to replace
ts=$(date +%Y%m%d%H%M%S)
[ -f "$SCRIPT" ] && cp "$SCRIPT" "$SCRIPT.bak.$ts" && echo "Backed up existing script → $SCRIPT.bak.$ts"
[ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.bak.$ts" && echo "Backed up settings → $SETTINGS.bak.$ts"

cat > "$SCRIPT" <<'STATUSLINE'
#!/usr/bin/env bash
# Claude Code statusLine command
# Receives JSON via stdin; prints colored lines to stdout.

input=$(cat)

# ANSI colors
LABEL=$'\033[38;5;180m'    # tan/khaki
VALUE=$'\033[97m'           # bright white
SEP=$'\033[90m'             # dim grey
ACCENT=$'\033[38;5;87m'     # bright cyan
RESET=$'\033[0m'

# Extract values
model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
effort=$(echo "$input" | jq -r '.effort.level // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_tokens=$(echo "$input" | jq -r '
  (.context_window.current_usage.input_tokens // 0) +
  (.context_window.current_usage.cache_creation_input_tokens // 0) +
  (.context_window.current_usage.cache_read_input_tokens // 0)')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "."')
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
fast_mode=$(echo "$input" | jq -r '.fast_mode // false')

session_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
session_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
weekly_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
weekly_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

short_cwd="${cwd/#$HOME/~}"
[ -z "$effort" ] && effort="off"

# --- Helpers ---

# Format a unix timestamp in local time (BSD/macOS and GNU/Linux date)
fmt_ts() {
	date -r "$1" "+$2" 2>/dev/null || date -d "@$1" "+$2"
}

# Convert a unix timestamp into "Xh Ym" / "Xd Yh" remaining
human_until() {
	local target="$1"
	if [ -z "$target" ] || [ "$target" = "null" ]; then
		echo "?"
		return
	fi
	local now diff
	now=$(date +%s)
	diff=$((target - now))
	if [ "$diff" -le 0 ]; then
		echo "now"
		return
	fi
	if [ "$diff" -lt 3600 ]; then
		echo "$((diff / 60))m"
	elif [ "$diff" -lt 86400 ]; then
		local h=$((diff / 3600))
		local m=$(((diff % 3600) / 60))
		if [ "$m" -gt 0 ]; then echo "${h}h ${m}m"; else echo "${h}h"; fi
	else
		local d=$((diff / 86400))
		local h=$(((diff % 86400) / 3600))
		if [ "$h" -gt 0 ]; then echo "${d}d ${h}h"; else echo "${d}d"; fi
	fi
}

# Convert a unix timestamp into "Sat May 10 2:00pm"
human_at() {
	local target="$1"
	if [ -z "$target" ] || [ "$target" = "null" ]; then
		echo "?"
		return
	fi
	fmt_ts "$target" "%a %b %-d %-I:%M%p" | sed -E 's/AM$/am/; s/PM$/pm/'
}

# --- Formatting ---

if [ -n "$ctx_tokens" ] && [ "$ctx_tokens" != "0" ]; then
	ctx_k=$(echo "$ctx_tokens" | awk '{printf "%.1fk", $1/1000}')
else
	ctx_k="-"
fi

if [ -n "$used_pct" ] && [ "$used_pct" != "null" ]; then
	used_pct_fmt=$(printf "%.1f%%" "$used_pct")
else
	used_pct_fmt="-"
fi

session_until=$(human_until "$session_reset")
weekly_at=$(human_at "$weekly_reset")

if [ -n "$session_reset" ] && [ "$session_reset" != "null" ]; then
	session_at=$(fmt_ts "$session_reset" "%-I:%M%p" | sed -E 's/AM$/am/; s/PM$/pm/')
else
	session_at=""
fi

session_pct_fmt=$([ -n "$session_pct" ] && [ "$session_pct" != "null" ] && printf "%.0f%%" "$session_pct" || echo "-")
weekly_pct_fmt=$([ -n "$weekly_pct" ] && [ "$weekly_pct" != "null" ] && printf "%.0f%%" "$weekly_pct" || echo "-")

branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
if [ -z "$branch" ]; then
	branch="no git"
	dirty_marker=""
else
	# Append * if working tree has uncommitted changes
	if [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]; then
		dirty_marker=" *"
	else
		dirty_marker=""
	fi
fi

if [ -n "$cost_usd" ] && [ "$cost_usd" != "null" ]; then
	cost_fmt=$(printf '$%.2f' "$cost_usd")
else
	cost_fmt=""
fi

if [ "$fast_mode" = "true" ]; then
	fast_marker=" ⚡"
else
	fast_marker=""
fi

PIPE="${SEP}|${RESET}"
SLASH="${SEP}/${RESET}"

line1="${VALUE}${model}${fast_marker}${RESET} ${SLASH} ${VALUE}${effort}${RESET}"
if [ -n "$cost_fmt" ]; then
	line2="${LABEL}Ctx:${RESET} ${VALUE}${ctx_k} (${used_pct_fmt})${RESET} ${PIPE} ${VALUE}${cost_fmt}${RESET}"
else
	line2="${LABEL}Ctx:${RESET} ${VALUE}${ctx_k} (${used_pct_fmt})${RESET}"
fi
line3="${LABEL}Session:${RESET} ${VALUE}${session_pct_fmt}${RESET} ${SEP}resets ${session_at} (${session_until})${RESET}"
line4="${LABEL}Weekly: ${RESET} ${VALUE}${weekly_pct_fmt}${RESET} ${SEP}resets ${weekly_at}${RESET}"
line5="${ACCENT}⎇ ${branch}${dirty_marker}${RESET} ${PIPE} ${ACCENT}${short_cwd}${RESET}"

printf '%s\n%s\n%s\n%s\n%s\n' "$line1" "$line2" "$line3" "$line4" "$line5"
STATUSLINE
chmod +x "$SCRIPT"

# Merge statusLine into settings.json, preserving everything else
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
tmp=$(mktemp)
jq '.statusLine = {"type": "command", "command": "bash $HOME/.claude/statusline-command.sh", "padding": 0}' "$SETTINGS" > "$tmp"
mv "$tmp" "$SETTINGS"

echo "Installed. Restart Claude Code (or start a new session) to see the status line."
