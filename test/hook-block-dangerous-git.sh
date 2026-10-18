#!/usr/bin/env bash
# Tests for dot_claude/hooks/executable_block-dangerous-git.sh, using a real
# throwaway git repository and a stub gh. No network.
# usage: bash test/hook-block-dangerous-git.sh   (needs bash, git, jq)
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hook="$root/dot_claude/hooks/executable_block-dangerous-git.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0 fail=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else fail=$((fail + 1)); echo "FAIL $1"; fi; }

# Repository with a branch "feat/x" one commit ahead of main.
repo="$work/repo"
git init -q -b main "$repo"
git -C "$repo" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
git -C "$repo" branch feat/x
git -C "$repo" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m other
tip=$(git -C "$repo" rev-parse feat/x)

# gh stub: prints $STUB_HEAD as the merged PR's head for any query.
mkdir -p "$work/bin"
cat > "$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STUB_LOG"
[ -n "${STUB_HEAD:-}" ] && echo "$STUB_HEAD"
exit 0
EOF
chmod +x "$work/bin/gh"
export STUB_LOG="$work/gh.log"

# run <command> [cwd]: feed the hook a PreToolUse payload; sets $rc and $err.
run() {
  local payload
  payload=$(jq -nc --arg c "$1" --arg d "${2:-$repo}" '{tool_input: {command: $c}, cwd: $d}')
  err=$(PATH="$work/bin:$PATH" bash "$hook" <<< "$payload" 2>&1 >/dev/null); rc=$?
}

run "git status";                                   check "plain commands pass" '[ $rc = 0 ]'
run "git push origin main";                         check "plain push passes" '[ $rc = 0 ]'
run "git reset --hard HEAD~1";                      check "reset --hard still blocked" '[ $rc = 2 ]'
run "git push --force origin main";                 check "force push still blocked" '[ $rc = 2 ]'
for c in "git -C $repo reset --hard" "git -c core.x=y reset --hard HEAD" "git -C $repo clean -fdx" \
         "git push -f origin main" "git push origin main --force-with-lease" "git -C $repo push --force" \
         "git checkout ." "git checkout -- ." "git restore ." "git restore --staged ." \
         "git branch --delete --force feat/x" "git -C $repo branch -fD feat/x"; do
  STUB_HEAD= run "$c"; check "blocked: $c" '[ $rc = 2 ]'
done
for c in "git checkout main" "git restore src/a.kt" "git push origin feat/fix-f" "git branch -d feat/x" "git log --format=-f"; do
  run "$c"; check "allowed: $c" '[ $rc = 0 ]'
done

STUB_HEAD=$tip run "git branch -D feat/x"
check "merged PR with same head: delete allowed" '[ $rc = 0 ]'
check "asks GitHub about that branch" 'grep -q -- "--head feat/x --state merged" "$STUB_LOG"'

STUB_HEAD=$tip run "git -C $repo branch -D feat/x" "$work"
check "-C <dir> form allowed" '[ $rc = 0 ]'
: > "$STUB_LOG"; STUB_HEAD= run "git -C $repo branch -D feat/x" "$work"
check "-C <dir> form is checked, not skipped" '[ $rc = 2 ] && [ -s "$STUB_LOG" ]'

STUB_HEAD=0000000000000000000000000000000000000000 run "git branch -D feat/x"
check "local commits not in the PR: blocked" '[ $rc = 2 ] && [[ $err == *"commits the merged PR does not"* ]]'

STUB_HEAD= run "git branch -D feat/x"
check "no merged PR: blocked" '[ $rc = 2 ] && [[ $err == *"no merged PR"* ]]'

STUB_HEAD=$tip run "git branch -D feat/missing"
check "unknown branch: blocked" '[ $rc = 2 ] && [[ $err == *"no local branch"* ]]'

: > "$STUB_LOG"
for c in "git branch -D feat/x && git reset --hard" "git branch -D feat/x; rm -rf /tmp/x" \
         "git branch -D \$(git branch --show-current)" "git branch -D feat/x | cat" \
         "git branch -D feat/x feat/y" "git branch -D -f feat/x"; do
  STUB_HEAD=$tip run "$c"
  check "blocked: $c" '[ $rc = 2 ]'
done
check "rejected forms never reach GitHub" '[ ! -s "$STUB_LOG" ]'

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
