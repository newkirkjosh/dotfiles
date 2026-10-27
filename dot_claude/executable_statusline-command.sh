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
# Use \x1f (unit separator) instead of \t: bash `read` treats an all-whitespace
# IFS as "collapse runs and trim edges", which silently drops empty fields
# (context_window/rate_limits are absent on first launch or right after
# /clear) and shifts everything left — e.g. model ends up in used's slot.
IFS=$'\x1f' read -r cwd used model five_hour five_reset < <(printf '%s' "$input" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
cwd       = (d.get("workspace") or {}).get("current_dir") or d.get("cwd") or ""
used      = (d.get("context_window") or {}).get("used_percentage")
model     = (d.get("model") or {}).get("display_name") or ""
fh        = (d.get("rate_limits") or {}).get("five_hour") or {}
five_hour = fh.get("used_percentage")
reset     = fh.get("resets_at")
# resets_at may be epoch seconds or an ISO-8601 string; normalise to epoch.
r = ""
if isinstance(reset, (int, float)):
    r = str(int(reset))
elif isinstance(reset, str) and reset:
    from datetime import datetime
    try:
        r = str(int(datetime.fromisoformat(reset.replace("Z", "+00:00")).timestamp()))
    except ValueError:
        pass
u = str(used) if used is not None else ""
f = str(five_hour) if five_hour is not None else ""
print("\x1f".join([cwd, u, model, f, r]))
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

# Session usage limit (5-hour window). rate_limits is absent on first launch
# and right after /clear, so keep the last value seen and reuse it until its
# window resets; a stale reading is marked with "~".
session_limit=""
cache="${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}/claude-statusline-5h"
now=$(date +%s)
stale=""
if [ -n "$five_hour" ]; then
  # Write via a temp file in the same directory, then rename, so a reader
  # never sees a partial line and an existing symlink is replaced, not followed.
  tmp=$(mktemp "${cache}.XXXXXX" 2>/dev/null) \
    && printf '%s %s\n' "$five_hour" "$five_reset" > "$tmp" && mv -f "$tmp" "$cache" \
    || rm -f "${tmp:-}"
elif [ -f "$cache" ] && [ ! -L "$cache" ] && [ -O "$cache" ]; then
  read -r c_pct c_reset < "$cache" || true
  [[ ${c_pct:-} =~ ^[0-9]+(\.[0-9]+)?$ ]] || c_pct=""
  [[ ${c_reset:-} =~ ^[0-9]+$ ]] || c_reset=""
  if [ -n "$c_pct" ] && { [ -z "$c_reset" ] || [ "$c_reset" -gt "$now" ]; }; then
    five_hour=$c_pct five_reset=${c_reset:-} stale="~"
  fi
fi
if [ -n "$five_hour" ]; then
  reset_str=""
  if [ -n "$five_reset" ] && [ "$five_reset" -gt "$now" ] 2>/dev/null; then
    reset_str=" ↻$(date -d "@$five_reset" +%H:%M)"
  fi
  session_limit=" ${C_YELLOW}5h:${stale}$(printf '%.0f' "$five_hour")%${reset_str}${C_RESET}"
fi

# Model
model_str=""
[ -n "$model" ] && model_str=" ${C_CYAN}${model}${C_RESET}"

printf "%s%s%s%s%s%s%s%s%s" \
  "$C_BLUE" "$dir_display" "$C_RESET" \
  "$git_branch" "$git_status_str" \
  "$ctx" "$session_limit" "$model_str"
