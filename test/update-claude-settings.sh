#!/usr/bin/env bash
# Tests .chezmoiscripts/run_onchange_after_update-claude-settings.sh.tmpl
# against a throwaway HOME: managed keys are merged in, keys the user added
# survive, and keys listed under claude.retired are deleted.
set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0

check() { # name, condition
    if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; fail=1; fi
}

chezmoi --source "$root" execute-template \
    < "$root/.chezmoiscripts/run_onchange_after_update-claude-settings.sh.tmpl" \
    > "$tmp/update.sh" || { echo "FAIL template did not render"; exit 1; }

run() { # settings.json content; leaves the result in $tmp/home/.claude/settings.json
    rm -rf "$tmp/home"; mkdir -p "$tmp/home/.claude"
    printf '%s' "$1" > "$tmp/home/.claude/settings.json"
    HOME="$tmp/home" bash "$tmp/update.sh" > "$tmp/out" 2>&1
}
get() { jq -c "$1" "$tmp/home/.claude/settings.json"; }

# A machine that had the retired keys, plus keys the user set themselves.
run '{"env":{"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS":"1","MY_VAR":"x"},"teammateMode":"tmux","model":"opus"}'
check "the retired env key is deleted" '[ "$(get ".env | has(\"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS\")")" = false ]'
check "the retired top-level key is deleted" '[ "$(get "has(\"teammateMode\")")" = false ]'
check "the user's other env key survives" '[ "$(get ".env.MY_VAR")" = "\"x\"" ]'
check "the user's own top-level key survives" '[ "$(get ".model")" = "\"opus\"" ]'
check "managed keys are merged in" '[ "$(get ".hooks.PreToolUse[0].hooks[0].command")" = "\"~/.claude/hooks/block-dangerous-git.sh\"" ]'

# An env holding only the retired key is removed rather than left empty.
run '{"env":{"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS":"1"}}'
check "an env left empty is removed" '[ "$(get "has(\"env\")")" = false ]'

# A fresh machine with no settings file at all.
rm -rf "$tmp/home"; mkdir -p "$tmp/home"
HOME="$tmp/home" bash "$tmp/update.sh" > "$tmp/out" 2>&1
check "a missing settings file is created without retired keys" \
    '[ "$(get "has(\"teammateMode\")")" = false ] && [ "$(get ".agentPushNotifEnabled")" = true ]'

exit $fail
