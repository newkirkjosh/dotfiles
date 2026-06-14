#!/usr/bin/env bash
# Claude Code status line — mirrors Starship Tokyo Night config:
# dir  branch git-status  ctx% model  5h-limit
input=$(cat)

# Tokyo Night palette (dimmed-safe ANSI approximations)
C_BLUE=$'\e[38;5;111m'    # #7aa2f7 — directory
C_PURPLE=$'\e[38;5;141m'  # #bb9af7 — git branch
C_YELLOW=$'\e[38;5;179m'  # #e0af68 — git status
C_GREEN=$'\e[38;5;114m'   # #9ece6a — cmd duration / ctx
C_CYAN=$'\e[38;5;117m'    # #7dcfff — model
C_RESET=$'\e[0m'

# Parse JSON in one Python pass.
IFS=$'\t' read -r cwd used model five_hour < <(printf '%s' "$input" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
cwd       = (d.get("workspace") or {}).get("current_dir") or d.get("cwd") or ""
used      = (d.get("context_window") or {}).get("used_percentage")
model     = (d.get("model") or {}).get("display_name") or ""
five_hour = ((d.get("rate_limits") or {}).get("five_hour") or {}).get("used_percentage")
print(f"{cwd}\t{''.join(str(used) if used is not None else '')}\t{model}\t{''.join(str(five_hour) if five_hour is not None else '')}")
')

# Directory — truncate to 3 components, matching starship truncation_length=3
dir_display=""
if [ -n "$cwd" ]; then
  home_rel="${cwd/#$HOME/~}"
  IFS='/' read -ra parts <<< "$home_rel"
  total=${#parts[@]}
  if [ "$total" -le 3 ]; then
    dir_display="$home_rel"
  else
    dir_display=".../${parts[$((total-2))]}/${parts[$((total-1))]}"
  fi
fi

# Git branch + status (skip optional locks)
git_branch=""
git_status_str=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir --no-optional-locks -q > /dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
           || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    git_branch=" ${C_PURPLE} ${branch}${C_RESET}"
  fi
  # Collect status indicators matching starship git_status all_status+ahead_behind
  stati=""
  git -C "$cwd" --no-optional-locks status --porcelain=v1 -b 2>/dev/null | while IFS= read -r line; do
    case "$line" in
      \?\?*)         printf '?';;
      \ M*|M\ *|MM*) printf '!';;
      \ D*|D\ *)     printf '✘';;
      A\ *|\ A*)     printf '+';;
      R\ *|\ R*)     printf '»';;
    esac
  done | read -r stati 2>/dev/null || true
  # Ahead/behind
  ab=$(git -C "$cwd" --no-optional-locks rev-list --left-right --count "@{upstream}...HEAD" 2>/dev/null)
  if [ -n "$ab" ]; then
    behind=$(echo "$ab" | awk '{print $1}')
    ahead=$(echo "$ab" | awk '{print $2}')
    [ "$behind" -gt 0 ] 2>/dev/null && stati="${stati}⇣"
    [ "$ahead"  -gt 0 ] 2>/dev/null && stati="${stati}⇡"
  fi
  [ -n "$stati" ] && git_status_str=" ${C_YELLOW}${stati}${C_RESET}"
fi

# Context usage
ctx=""
[ -n "$used" ] && ctx=" ${C_GREEN}ctx:$(printf '%.0f' "$used")%${C_RESET}"

# Session usage limit (5-hour window)
session_limit=""
[ -n "$five_hour" ] && session_limit=" ${C_YELLOW}5h:$(printf '%.0f' "$five_hour")%${C_RESET}"

# Model
model_str=""
[ -n "$model" ] && model_str=" ${C_CYAN}${model}${C_RESET}"

printf "%s%s%s%s%s%s%s%s%s" \
  "$C_BLUE" "$dir_display" "$C_RESET" \
  "$git_branch" "$git_status_str" \
  "$ctx" "$session_limit" "$model_str"
