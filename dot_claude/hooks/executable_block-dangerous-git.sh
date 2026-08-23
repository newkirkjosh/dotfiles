#!/bin/bash
# Adapted from mattpocock/skills' git-guardrails-claude-code.
# Plain "git push" is deliberately NOT blocked here — the user's CLAUDE.md
# safety posture is "confirm before push," not "never push," and the
# permission-prompt flow already covers that. Only irreversible/destructive
# operations get a hard block.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

DANGEROUS_PATTERNS=(
  "git reset --hard"
  "git clean -fd"
  "git clean -f"
  "git branch -D"
  "git checkout \."
  "git restore \."
  "push --force"
  "push -f"
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "BLOCKED: '$COMMAND' matches dangerous pattern '$pattern'. The user has prevented you from doing this without explicit approval." >&2
    exit 2
  fi
done

exit 0
