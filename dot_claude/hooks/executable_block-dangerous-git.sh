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
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Extended regexes. G matches `git` plus any -C <dir> / -c <key=val> options,
# so `git -C repo reset --hard` is caught like `git reset --hard`.
G='git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+'
BRANCH_DELETE="${G}branch[[:space:]]+(-D|-[a-zA-Z]*D[a-zA-Z]*|--delete[[:space:]]+--force|--force[[:space:]]+--delete)([[:space:]]|$)"
DANGEROUS_PATTERNS=(
  "${G}reset[[:space:]]+--hard"
  "${G}clean[[:space:]]+-[a-zA-Z]*f"
  "$BRANCH_DELETE"
  "${G}checkout[[:space:]]+(--[[:space:]]+)?\.([[:space:]]|$)"
  "${G}restore[[:space:]]+.*\.([[:space:]]|$)"
  "push([[:space:]]+[^[:space:]]+)*[[:space:]]+(--force[^[:space:]]*|-f)([[:space:]]|$)"
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
  local re='^[[:space:]]*git[[:space:]]+(-C[[:space:]]+([^[:space:]]+)[[:space:]]+)?branch[[:space:]]+-D[[:space:]]+([A-Za-z0-9._/-]+)[[:space:]]*$'
  [[ $COMMAND =~ $re ]] || { echo "only 'git [-C <dir>] branch -D <branch>' is checked"; return 1; }
  local dir=${BASH_REMATCH[2]:-$CWD} branch=${BASH_REMATCH[3]}
  dir=${dir/#\~/$HOME}
  [ -n "$dir" ] && [ -d "$dir" ] || { echo "no repository directory"; return 1; }
  local tip head
  tip=$(git -C "$dir" rev-parse --verify --quiet "refs/heads/$branch") || { echo "no local branch $branch"; return 1; }
  head=$(cd "$dir" && timeout 15 gh pr list --head "$branch" --state merged --limit 1 \
           --json headRefOid -q '.[0].headRefOid' 2>/dev/null)
  [ -n "$head" ] || { echo "no merged PR for $branch"; return 1; }
  [ "$head" = "$tip" ] || { echo "local $branch has commits the merged PR does not"; return 1; }
  return 0
}

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    if [ "$pattern" = "$BRANCH_DELETE" ]; then
      reason=$(merged_branch_delete_ok) && exit 0
      block "$pattern" "$reason"
    fi
    block "$pattern"
  fi
done

exit 0
