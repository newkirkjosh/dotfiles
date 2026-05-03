#!/usr/bin/env bash
# Validates the chezmoi-managed dotfiles repo without applying anything to the
# real home directory. Designed to run locally or in CI.
#
# Checks:
#   1. .chezmoidata/*.yaml files parse as valid YAML
#   2. .chezmoiscripts/*.sh.tmpl render via chezmoi and pass `bash -n`
#   3. Key templates render without errors via `chezmoi cat`
#   4. `chezmoi diff --no-pager` does not error out
#
# Usage: test/validate.sh   (run from repo root or anywhere — auto-resolves)

set -euo pipefail

# ─── Colors ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; RESET='\033[0m'
step()    { printf "${BLUE}→${RESET} %s\n" "$1"; }
success() { printf "${GREEN}✓${RESET} %s\n" "$1"; }
warn()    { printf "${YELLOW}⚠${RESET} %s\n" "$1"; }
err()     { printf "${RED}✗${RESET} %s\n" "$1" >&2; }

# ─── Paths ───────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

FAILURES=0
record_fail() { FAILURES=$((FAILURES + 1)); err "$1"; }

# ─── Tool checks ─────────────────────────────────────────────────────
require() {
    if ! command -v "$1" >/dev/null 2>&1; then
        err "Required tool not found: $1"
        exit 2
    fi
}
require chezmoi
require bash

YAML_PARSER=""
if command -v yq >/dev/null 2>&1; then
    YAML_PARSER="yq"
elif command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" >/dev/null 2>&1; then
    YAML_PARSER="python"
else
    err "Need either yq or python3 with PyYAML to validate YAML files"
    exit 2
fi

# ─── chezmoi source dir ──────────────────────────────────────────────
# Tell chezmoi to operate against this repo, regardless of cwd or installed
# config. --source overrides the configured source path for the duration of
# the command.
CHEZMOI=(chezmoi --source="$REPO_DIR")

step "Validating repo at $REPO_DIR"

# ─── 1. YAML data files ──────────────────────────────────────────────
step "Checking .chezmoidata/*.yaml files parse"
shopt -s nullglob
YAML_FILES=("$REPO_DIR"/.chezmoidata/*.yaml "$REPO_DIR"/.chezmoidata/*.yml)
shopt -u nullglob

if [ ${#YAML_FILES[@]} -eq 0 ]; then
    warn "No YAML files found under .chezmoidata/"
else
    for f in "${YAML_FILES[@]}"; do
        rel="${f#"$REPO_DIR"/}"
        case "$YAML_PARSER" in
            yq)
                if yq eval '.' "$f" >/dev/null 2>&1; then
                    success "yaml ok: $rel"
                else
                    record_fail "yaml parse failed: $rel"
                fi
                ;;
            python)
                if python3 -c "import sys, yaml; yaml.safe_load(open(sys.argv[1]))" "$f" >/dev/null 2>&1; then
                    success "yaml ok: $rel"
                else
                    record_fail "yaml parse failed: $rel"
                fi
                ;;
        esac
    done
fi

# ─── 2. Shell script templates: render + bash -n ─────────────────────
step "Rendering and syntax-checking .chezmoiscripts/*.sh.tmpl"
shopt -s nullglob
SCRIPT_TMPLS=("$REPO_DIR"/.chezmoiscripts/*.sh.tmpl)
shopt -u nullglob

if [ ${#SCRIPT_TMPLS[@]} -eq 0 ]; then
    warn "No script templates found under .chezmoiscripts/"
else
    TMP_RENDER="$(mktemp -d)"
    trap 'rm -rf "$TMP_RENDER"' EXIT
    for tmpl in "${SCRIPT_TMPLS[@]}"; do
        rel="${tmpl#"$REPO_DIR"/}"
        out="$TMP_RENDER/$(basename "$tmpl" .tmpl)"
        if ! "${CHEZMOI[@]}" execute-template <"$tmpl" >"$out" 2>/dev/null; then
            record_fail "template render failed: $rel"
            continue
        fi
        # Some templates intentionally render to nothing on non-matching distros.
        if [ ! -s "$out" ]; then
            success "render ok (empty for this distro): $rel"
            continue
        fi
        if bash -n "$out" 2>/dev/null; then
            success "syntax ok: $rel"
        else
            record_fail "bash syntax error after render: $rel"
            bash -n "$out" 2>&1 | sed 's/^/    /' >&2 || true
        fi
    done
fi

# ─── 3. Spot-check that key files render via chezmoi cat ─────────────
step "Spot-checking key file outputs via chezmoi cat"
SPOT_CHECKS=(
    "$HOME/.gitconfig"
    "$HOME/.zshrc"
)
for target in "${SPOT_CHECKS[@]}"; do
    rel="${target#"$HOME/"}"
    if "${CHEZMOI[@]}" cat "$target" >/dev/null 2>&1; then
        success "renders: ~/$rel"
    else
        # chezmoi cat exits non-zero if the source file does not exist OR
        # if rendering fails. Differentiate so missing-file is non-fatal.
        if "${CHEZMOI[@]}" managed | grep -qx "$rel"; then
            record_fail "render failed: ~/$rel"
        else
            warn "not managed (skipped): ~/$rel"
        fi
    fi
done

# ─── 4. chezmoi diff sanity (no execution errors) ────────────────────
step "Running chezmoi diff (should not error)"
if "${CHEZMOI[@]}" diff --no-pager >/dev/null 2>&1; then
    success "chezmoi diff completed without error"
else
    # diff exits non-zero only on actual error, not on diffs being present
    record_fail "chezmoi diff errored — check templates / data"
fi

# ─── Summary ─────────────────────────────────────────────────────────
echo
if [ "$FAILURES" -eq 0 ]; then
    success "All validation checks passed"
    exit 0
else
    err "$FAILURES check(s) failed"
    exit 1
fi
