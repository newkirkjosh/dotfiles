#!/bin/bash
# Adapted from mattpocock/skills' git-guardrails-claude-code.
# Plain "git push" is deliberately NOT blocked here — the user's CLAUDE.md
# safety posture is "confirm before push," not "never push," and the
# permission-prompt flow already covers that. Only irreversible/destructive
# operations get a hard block.
#
# Merged branches are removed with `wt remove <branch>` (worktrunk), which
# deletes a branch only when its changes are already in the default branch,
# squash merges included, so force-deleting stays blocked without exception.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# Limit: this is a guardrail against mistakes, not an adversary. Flags that
# only exist after expansion (`git push $FLAGS`, `$(...)`) can't be seen here.
#
# What the patterns are matched against: quote characters removed (the shell
# removes them too, so "-f" is -f), and ; & | that are quoted or
# backslash-escaped turned into _, so only real separators end a command.
normalize() {
  # The whole command is one string: quotes span lines (a multi-line commit
  # message), so quote state must survive newlines.
  awk '{ s = s (NR > 1 ? "\n" : "") $0 }
  END {
    out = ""; q = ""
    for (i = 1; i <= length(s); i++) {
      c = substr(s, i, 1)
      if (q == "" && c == "\\") { i++; n = substr(s, i, 1); out = out (n ~ /[;&|]/ ? "_" : n); continue }
      if (q == "" && (c == "\047" || c == "\"")) { q = c; continue }
      if (q != "" && c == q) { q = ""; continue }
      if (q != "" && c ~ /[;&|]/) c = "_"
      out = out c
    }
    print out
  }'
}
MATCH=$(printf '%s\n' "$COMMAND" | normalize)

# Extended regexes. G matches `git` plus any -C <dir> / -c <key=val> options,
# so `git -C repo reset --hard` is caught like `git reset --hard`.
G='git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+'
BRANCH_DELETE="${G}branch[[:space:]]+(-D|-[a-zA-Z]*D[a-zA-Z]*|--delete[[:space:]]+--force|--force[[:space:]]+--delete)([[:space:]]|$)"
# A = any further arguments of the same command, so flags in front of the
# dangerous one don't hide it. Tokens stop at ; & | so a later command in a
# chain (`git push && tail -n +2`) isn't read as this one's arguments.
A='([[:space:]]+[^[:space:];&|]+)*'
DANGEROUS_PATTERNS=(
  "${G}reset${A}[[:space:]]+--hard"
  "${G}clean${A}[[:space:]]+(-[a-zA-Z]*f|--force)"
  "$BRANCH_DELETE"
  "${G}checkout${A}[[:space:]]+\."
  "${G}restore${A}[[:space:]]+\."
  "push${A}[[:space:]]+(--force[^[:space:]]*|-[a-zA-Z]*f[a-zA-Z]*|\+[^[:space:]]+)([[:space:]]|$)"
  # worktrunk: removing a worktree with uncommitted changes or an unmerged branch.
  # Plain `wt remove` refuses both on its own.
  "wt${A}[[:space:]]+remove${A}[[:space:]]+(-[a-zA-Z]*[fD][a-zA-Z]*|--force|--force-delete)([[:space:]]|$)"
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if printf '%s\n' "$MATCH" | grep -qE "$pattern"; then
    echo "BLOCKED: '$COMMAND' matches dangerous pattern '$pattern'. The user has prevented you from doing this without explicit approval." >&2
    exit 2
  fi
done

exit 0
