#!/usr/bin/env bash
# Tests .chezmoiscripts/run_onchange_after_install-skills.sh.tmpl with git and
# gh stubbed on PATH: no network, no real catalogs, no real skill links.
set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0

check() { # name, condition
    if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; fail=1; fi
}

# Render the template's only variable without needing chezmoi.
sed 's|{{ .chezmoi.homeDir }}|/nonexistent-home|' \
    "$root/.chezmoiscripts/run_onchange_after_install-skills.sh.tmpl" > "$tmp/install-skills.sh"

mkdir -p "$tmp/bin"
# A fake catalog checkout whose installer records that it ran, or fails when
# the catalog is named in $FAIL_INSTALL.
cat > "$tmp/make-catalog" <<'EOF'
#!/usr/bin/env bash
dest="$1"; name="$(basename "$dest")"
mkdir -p "$dest/.git" "$dest/scripts"
cat > "$dest/scripts/install.sh" <<INNER
#!/usr/bin/env bash
case " \${FAIL_INSTALL:-} " in *" $name "*) exit 1;; esac
echo "$name" >> "\$LOG"
INNER
chmod +x "$dest/scripts/install.sh"
EOF
chmod +x "$tmp/make-catalog"
# SSH clone always fails; gh clone fails for catalogs named in $FAIL_GH.
cat > "$tmp/bin/git" <<'EOF'
#!/usr/bin/env bash
[ "$1" = clone ] && exit 128
exit 0
EOF
cat > "$tmp/bin/gh" <<EOF
#!/usr/bin/env bash
case "\$1 \$2" in
  "auth status") exit 0;;
  "repo clone") name="\${3#*/}"
     case " \${FAIL_GH:-} " in *" \$name "*) exit 1;; esac
     "$tmp/make-catalog" "\$4";;
esac
EOF
chmod +x "$tmp/bin/git" "$tmp/bin/gh"

run() { # dir [output file]; prints exit code
    PATH="$tmp/bin:$PATH" SKILL_CATALOGS_DIR="$1" LOG="$1/log" \
        bash "$tmp/install-skills.sh" > "${2:-$1.out}" 2>&1
    echo $?
}

# A gh clone failure skips only that catalog.
d="$tmp/a"; mkdir -p "$d"
rc="$(FAIL_GH=dnd-skills run "$d")"
check "a failed gh clone is skipped, not fatal" '[ "$rc" = 0 ]'
check "the other catalogs still install" '[ "$(tr "\n" " " < "$d/log")" = "skills unifi-skills " ]'
check "the skipped catalog is named" 'grep -q "could not clone newkirkjosh/dnd-skills" "$d.out"'

# A failing install doesn't stop later catalogs, but fails the run.
d="$tmp/b"; mkdir -p "$d"
for n in skills dnd-skills unifi-skills; do "$tmp/make-catalog" "$d/$n"; done
rc="$(FAIL_INSTALL=skills run "$d")"
check "a failed install exits non-zero" '[ "$rc" = 1 ]'
check "later catalogs still install" '[ "$(tr "\n" " " < "$d/log")" = "dnd-skills unifi-skills " ]'
check "the failure says how to recover" 'grep -q "install failed for: skills" "$d.out" && grep -q "pull --ff-only" "$d.out"'

# A base directory that can't be created fails the run, so it is retried.
: > "$tmp/not-a-dir"
rc="$(run "$tmp/not-a-dir/sub" "$tmp/c.out")"
check "an uncreatable base directory exits non-zero" '[ "$rc" = 1 ] && grep -q "could not create" "$tmp/c.out"'

exit $fail
