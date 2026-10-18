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
         "git branch --delete --force feat/x" "git -C $repo branch -fD feat/x" \
         "git checkout ./src" "git checkout HEAD -- ./src" "git restore ./a.txt" "git restore --source=HEAD ." \
         "git reset -q --hard" "git reset --quiet --hard HEAD~1" "git clean -d --force" "git clean -n -f" \
         "git push -fu origin main" "git push -uf origin feat/x" "git push origin +main" "git push origin +HEAD:main" \
         "git push origin 'a|b' -f" "git push origin \"a;b\" --force" "git push origin a\\;b --force" "git push \"-f\" origin" \
         "git push origin '+main'" "git reset 'x;y' --hard" "git 'reset' --hard" "git clean \"-fd\"" "git branch '-D' x" \
         $'git commit -m "a\nb" && git push -f origin main' $'echo "x\ny"\ngit reset --hard' \
         "wt remove -D feat/x" "wt remove --force-delete feat/x" "wt remove -f" "wt remove --force feat/x" "wt -C /r remove -D x" \
         "wt -y remove -D x" "wt --config /c.toml remove --force-delete x" "wt -v -C /r remove -yD x" "/usr/bin/wt remove -f"; do
  STUB_HEAD= run "$c"; check "blocked: $c" '[ $rc = 2 ]'
done
for c in "git checkout main" "git restore src/a.kt" "git push origin feat/fix-f" "git branch -d feat/x" "git log --format=-f" \
         "git push -q origin --delete feat/x && tail -n +2 f" "git push origin x && rm -f tmp" "git push origin x; ls -f" \
         "git reset HEAD; echo --hard" "git clean -n | grep -f pats" "git checkout main && cat ./README" \
         $'git commit -m "subject\n\nbody line\n" && git push -u origin feat/x 2>&1 | grep -v \'^remote\'; gh pr create --body-file b.md' \
         $'git commit -m "a\nb" && git push origin x && tail -n +2 f' \
         "wt remove" "wt remove feat/x" "wt list --full" "wt switch --create feat/y"; do
  run "$c"; check "allowed: $c" '[ $rc = 0 ]'
done

: > "$STUB_LOG"
for c in "git branch -D feat/x" "git -C $repo branch -D feat/x" "git branch -D feat/x && git reset --hard" \
         "git branch -D \$(git branch --show-current)" "git branch -D feat/x feat/y" "git branch -D -f feat/x"; do
  STUB_HEAD=$tip run "$c"
  check "force-delete always blocked: $c" '[ $rc = 2 ]'
done
check "the hook never calls GitHub" '[ ! -s "$STUB_LOG" ]'

# Differential against the original substring patterns: anything they blocked
# must stay blocked, across spellings and prefixes.
old_patterns=("git reset --hard" "git clean -fd" "git clean -f" "git branch -D" "git checkout \." "git restore \." "push --force" "push -f")
old_blocks() { local p; for p in "${old_patterns[@]}"; do echo "$1" | grep -qE "$p" && return 0; done; return 1; }
regressions=0 total=0
for verb in "reset --hard" "reset --hard HEAD~2" "clean -f" "clean -fd" "clean -fdx" "clean -ff" "branch -D x" "branch -Dq x" "branch -D" \
            "checkout ." "checkout ./a" "checkout .." "checkout .gitignore" "restore ." "restore ./a" "restore .x" \
            "push --force" "push --force-with-lease" "push -f" "push -fu o m" "push -force" "push -fq" "push origin main -f" "push origin --force"; do
  for g in "git " "/usr/bin/git " "git -C /r " "git -c a=b " "\\git " "command git "; do
    for pre in "" "cd /x && " "sudo " "FOO=1 " "echo hi; " "("; do
      c="$pre$g$verb"; total=$((total + 1))
      old_blocks "$c" || continue
      STUB_HEAD= run "$c" "/nonexistent"
      [ $rc = 2 ] || { regressions=$((regressions + 1)); echo "  regression: $c"; }
    done
  done
done
check "no regression against the original patterns ($total commands)" '[ $regressions = 0 ]'

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
