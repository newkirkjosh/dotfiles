#!/usr/bin/env bash
# Claude Code status line — mirrors p10k: user@host dir git-branch ctx% model
input=$(cat)

# Colors — $'\e[...]' embeds the real ESC byte so escapes work via %s too.
C_GREEN=$'\e[0;32m'
C_BLUE=$'\e[0;34m'
C_YELLOW=$'\e[0;33m'
C_CYAN=$'\e[0;36m'
C_MAGENTA=$'\e[0;35m'
C_RESET=$'\e[0m'

# Parse the JSON payload in one Python pass (no jq dependency).
IFS=$'\t' read -r cwd used model < <(printf '%s' "$input" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
cwd      = (d.get("workspace") or {}).get("current_dir") or d.get("cwd") or ""
used     = (d.get("context_window") or {}).get("used_percentage")
model    = (d.get("model") or {}).get("display_name") or ""
used_str = "" if used is None else str(used)
print(f"{cwd}\t{used_str}\t{model}")
')

short_dir=$(basename "$cwd")
user=$(whoami)
host=$(hostname -s)

# Git branch (skip optional locks)
git_branch=""
if git -C "$cwd" rev-parse --git-dir -q --no-optional-locks > /dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  [ -n "$branch" ] && git_branch=" ${C_YELLOW} ${branch}${C_RESET}"
fi

# Context usage
ctx=""
[ -n "$used" ] && ctx=" ${C_CYAN}ctx:$(printf '%.0f' "$used")%${C_RESET}"

# Model
model_str=""
[ -n "$model" ] && model_str=" ${C_MAGENTA}${model}${C_RESET}"

printf "%s%s@%s%s %s%s%s%s%s%s" \
  "$C_GREEN" "$user" "$host" "$C_RESET" \
  "$C_BLUE" "$short_dir" "$C_RESET" \
  "$git_branch" "$ctx" "$model_str"
