#!/usr/bin/env bash
# Tests for the global git hook dispatcher's secret scan (dot_config/git/hooks/_run),
# with gitleaks stubbed on PATH. No network.
# usage: bash test/git-hooks.sh   (needs bash and git)
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0 fail=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else fail=$((fail + 1)); echo "FAIL $1"; fi; }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com

# Hooks dir as installed: every hook name links to _run.
mkdir -p "$work/hooks" "$work/bin" "$work/nogl"
cp "$root/dot_config/git/hooks/executable__run" "$work/hooks/_run"
chmod +x "$work/hooks/_run"
ln -s _run "$work/hooks/pre-commit"
for t in git env bash cat dirname basename readlink; do ln -s "$(command -v "$t")" "$work/nogl/$t"; done

# gitleaks stub: logs its args; exits $STUB_RC.
cat > "$work/bin/gitleaks" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$work/gitleaks.args"
exit "\${STUB_RC:-0}"
EOF
chmod +x "$work/bin/gitleaks"

repo="$work/repo"
git init -q -b main "$repo"
git -C "$repo" config core.hooksPath "$work/hooks"
n=0
commit() { n=$((n + 1)); echo "$n" > "$repo/f$n"; git -C "$repo" add "f$n"; git -C "$repo" commit -q -m "c$n" > "$work/out" 2>&1; echo $? > "$work/rc"; }
rc() { cat "$work/rc"; }

PATH="$work/bin:$PATH" commit
check "clean scan lets the commit through" '[ "$(rc)" = 0 ]'
check "scans staged changes in pre-commit mode" 'grep -qx -- --staged "$work/gitleaks.args" && grep -qx -- --pre-commit "$work/gitleaks.args"'
check "redacts findings" 'grep -qx -- --redact "$work/gitleaks.args"'

STUB_RC=1 PATH="$work/bin:$PATH" commit
check "a finding blocks the commit" '[ "$(rc)" = 1 ] && grep -q "possible secret" "$work/out"'
check "the blocked change is not committed" '[ "$(git -C "$repo" rev-list --count HEAD)" = 1 ]'

git -C "$repo" reset -q
PATH="$work/nogl" commit
check "missing gitleaks warns and commits" '[ "$(rc)" = 0 ] && grep -q "gitleaks not installed" "$work/out"'

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
