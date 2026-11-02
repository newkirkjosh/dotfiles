#!/usr/bin/env bash
# Tests for .chezmoiscripts/run_after_install-go-tools.sh.tmpl, rendered with a
# test tool list, against stub go, mise and distrobox. No network, no real Go.
# usage: bash test/go-tools.sh
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpl="$root/.chezmoiscripts/run_after_install-go-tools.sh.tmpl"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0 fail=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else fail=$((fail + 1)); echo "FAIL $1"; fi; }

mkdir -p "$work/bin" "$work/home"
# go stub: logs each call with its environment; "install" writes the binary
# into GOBIN unless the module path contains "broken".
cat > "$work/bin/go" <<'STUB'
#!/usr/bin/env bash
echo "go $* GOBIN=${GOBIN:-} GOPRIVATE=${GOPRIVATE:-} CGO=${CGO_ENABLED:-} GIT=${GIT_CONFIG_KEY_0:-}=${GIT_CONFIG_VALUE_0:-}" >> "$STUB_LOG"
case "$1" in
  env) echo "${SAVED_GOPRIVATE:-}" ;;
  install)
    case "$2" in *broken*) exit 1 ;; esac
    p="${2%@*}"; n="${p##*/}"; [[ "$n" =~ ^v[0-9]+$ ]] && { p="${p%/*}"; n="${p##*/}"; }
    touch "$GOBIN/$n"; chmod +x "$GOBIN/$n" ;;
esac
STUB
# distrobox stub (Bazzite rendering): lists the container, runs `enter -- cmd`.
cat > "$work/bin/distrobox" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  list) echo "ID | NAME | STATUS"; echo "x | arch-dev | Up" ;;
  enter) shift; while [ "$1" != "--" ]; do shift; done; shift; exec "$@" ;;
esac
STUB
chmod +x "$work/bin/go" "$work/bin/distrobox"
export STUB_LOG="$work/go.log"

# render TOOL...: the script for these tools.
render() {
    local json
    json=$(printf '"%s",' "$@")
    chezmoi execute-template --source "$root" --override-data "{\"go_tools\":[${json%,}]}" < "$tmpl" > "$work/script.sh"
}
# run [PATH]: run the rendered script with a temporary HOME.
run() { : > "$STUB_LOG"; out=$(HOME="$work/home" PATH="${1:-$work/bin}:/usr/bin:/bin" bash "$work/script.sh" 2>&1); rc=$?; }

render "example.com/owner/tool/cmd/tool@latest" "example.com/owner/other/v2@latest" "github.com/newkirkjosh/private/cmd/private@latest"
SAVED_GOPRIVATE="corp.example.com/*" run
check "missing tools are installed"          '[ -x "$work/home/.local/bin/tool" ] && [ -x "$work/home/.local/bin/other" ] && [ -x "$work/home/.local/bin/private" ]'
check "binaries go to ~/.local/bin"          'grep -q "GOBIN=$work/home/.local/bin" "$STUB_LOG"'
check "static build"                         '! grep "go install" "$STUB_LOG" | grep -qv "CGO=0"'
check "saved GOPRIVATE is kept and extended" 'grep -q "GOPRIVATE=corp.example.com/\*,github.com/newkirkjosh/\*" "$STUB_LOG"'
check "SSH rewrite only for the owner"       'grep -q "GIT=url.git@github.com:newkirkjosh/.insteadOf=https://github.com/newkirkjosh/" "$STUB_LOG"'
check "exit 0"                               '[ "$rc" -eq 0 ]'

run
check "present tools are skipped (no go call)" '[ ! -s "$STUB_LOG" ] && [ "$rc" -eq 0 ]'

rm "$work/home/.local/bin/other"
run
check "a /vN module is found by its real name" '[ "$(grep -c "go install" "$STUB_LOG")" -eq 1 ] && grep -q "go install example.com/owner/other/v2@latest" "$STUB_LOG"'

render "example.com/owner/broken/cmd/broken@latest"
run
check "a failed install warns and exits 0"     '[ "$rc" -eq 0 ] && grep -q "will retry" <<<"$out"'
run
check "a failed install is retried next time"  'grep -q "go install example.com/owner/broken" "$STUB_LOG"'

mkdir -p "$work/nogo" && cp "$work/bin/distrobox" "$work/nogo/"
run "$work/nogo"
check "no Go warns and exits 0"                '[ "$rc" -eq 0 ] && grep -q "no Go found" <<<"$out"'

render
run
check "an empty list does nothing"             '[ "$rc" -eq 0 ] && [ -z "$out" ] && [ ! -s "$STUB_LOG" ]'

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
