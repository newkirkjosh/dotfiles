#!/bin/bash
# Adapted from mattpocock/skills' git-guardrails-claude-code.
# Plain "git push" is deliberately NOT blocked here — the user's CLAUDE.md
# safety posture is "confirm before push," not "never push," and the
# permission-prompt flow already covers that. Only irreversible/destructive
# operations get a hard block.
#
# One narrow exception: `git branch -D <branch>` on its own is allowed when
# GitHub reports that branch's PR as merged and the local branch still points
# at the PR's head commit. Squash merges leave such branches "unmerged" to git,
# so -d refuses them, yet deleting one loses nothing.

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
)

block() {
  echo "BLOCKED: '$COMMAND' matches dangerous pattern '$1'. The user has prevented you from doing this without explicit approval.${2:+ ($2)}" >&2
  exit 2
}

# Succeeds only for a lone `git [-C <dir>] branch -D <branch>` whose PR is
# merged with the same head commit. Prints why when it declines.
merged_branch_delete_ok() {
  # A single simple command: no chaining, pipes, substitutions or redirects.
  case "$COMMAND" in
    *';'*|*'&'*|*'|'*|*'`'*|*'$'*|*'>'*|*'<'*|*$'\n'*) echo "not a single command"; return 1 ;;
  esac
  # An explicit absolute -C path of plain characters means the same directory
  # to this hook and to git: no relative path or cwd guess, no quotes, escapes,
  # globs or ~ that the shell would rewrite before git sees them.
  local re='^[[:space:]]*git[[:space:]]+-C[[:space:]]+(/[A-Za-z0-9._/+-]*)[[:space:]]+branch[[:space:]]+-D[[:space:]]+([A-Za-z0-9._/-]+)[[:space:]]*$'
  [[ $COMMAND =~ $re ]] || { echo "only 'git -C <absolute path> branch -D <branch>' is checked"; return 1; }
  local dir=${BASH_REMATCH[1]} branch=${BASH_REMATCH[2]}
  case "$branch" in -*) echo "branch name looks like an option"; return 1 ;; esac
  [ -d "$dir" ] || { echo "no repository directory"; return 1; }
  local tip head
  tip=$(git -C "$dir" rev-parse --verify --quiet "refs/heads/$branch") || { echo "no local branch $branch"; return 1; }
  head=$(cd "$dir" && timeout 15 gh pr list --head "$branch" --state merged --limit 1 \
           --json headRefOid -q '.[0].headRefOid' 2>/dev/null)
  [ -n "$head" ] || { echo "no merged PR for $branch"; return 1; }
  [ "$head" = "$tip" ] || { echo "local $branch has commits the merged PR does not"; return 1; }
  return 0
}

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if printf '%s\n' "$MATCH" | grep -qE "$pattern"; then
    if [ "$pattern" = "$BRANCH_DELETE" ]; then
      reason=$(merged_branch_delete_ok) && exit 0
      block "$pattern" "$reason"
    fi
    block "$pattern"
  fi
done

exit 0
