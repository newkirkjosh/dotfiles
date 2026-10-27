#!/usr/bin/env bash
# Tests for dot_local/bin/executable_secret, with stub op and keyctl (a
# directory stands in for the keyring). No network, no real keyring.
# usage: bash test/secret.sh
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
secret="$root/dot_local/bin/executable_secret"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0 fail=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else fail=$((fail + 1)); echo "FAIL $1"; fi; }

mkdir -p "$work/bin" "$work/ring"
# op stub: logs each read; "op://v/bad/f" fails like a missing item.
cat > "$work/bin/op" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$STUB_LOG"
[ "$1 $2" = "read --no-newline" ] || exit 9
[ "$3" = "op://v/bad/f" ] && { echo "item not found" >&2; exit 1; }
printf 'value-of-%s' "$3"
EOF
# keyctl stub: keys are files named by description; ids are the description.
cat > "$work/bin/keyctl" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  padd)    cat > "$RING/$3"; echo "$3" ;;
  search)  [ -f "$RING/$4" ] && echo "$4" ;;
  pipe)    cat "$RING/$2" ;;
  timeout) echo "$3" > "$RING/.ttl-$2" ;;
  unlink)  rm -f "$RING/$2" ;;
  *) exit 9 ;;
esac
EOF
chmod +x "$work/bin/op" "$work/bin/keyctl"
printf '# comment\napi  op://v/api/f\nbad  op://v/bad/f\n' > "$work/refs"

export STUB_LOG="$work/op.log" RING="$work/ring" SECRET_REFS="$work/refs" SECRET_NO_HOST=1
run() { out=$(PATH="$work/bin:$PATH" bash "$secret" "$@" 2>"$work/err"); rc=$?; err=$(cat "$work/err"); }

run get api;  check "get loads from 1Password on a miss" '[ $rc = 0 ] && [ "$out" = "value-of-op://v/api/f" ]'
check "the secret reaches op only as a reference" 'grep -q "read --no-newline op://v/api/f" "$STUB_LOG"'
check "default TTL is 12h" '[ "$(cat "$RING/.ttl-secret:api")" = 43200 ]'
run get api;  check "get hits the cache on the second call" '[ "$out" = "value-of-op://v/api/f" ] && [ "$(wc -l < "$STUB_LOG")" = 1 ]'
run list;     check "list marks cached names" 'grep -qx "api cached" <<< "$out" && grep -qx "bad -" <<< "$out"'
run list;     check "list skips comments" '! grep -q "^#" <<< "$out"'
run get bad;  check "a failed op read exits non-zero" '[ $rc != 0 ] && grep -q "could not read" <<< "$err"'
check "a failed read caches nothing" '[ ! -s "$RING/secret:bad" ]'
run get nope; check "an unknown name says so" '[ $rc != 0 ] && grep -q "not in" <<< "$err"'
run get;      check "get without a name is a usage error" '[ $rc != 0 ] && grep -q usage <<< "$err"'
run clear api; check "clear drops the key" '[ ! -f "$RING/secret:api" ] && grep -qx "cleared api" <<< "$out"'
rm -f "$RING/.ttl-secret:api"; SECRET_TTL=0 run load api; check "load reports what it loaded" '[ $rc = 0 ] && grep -qx "loaded api" <<< "$out"' check "TTL 0 leaves the key without expiry" '[ ! -f "$RING/.ttl-secret:api" ]'
SECRET_REFS="$work/none" run get uncached; check "a missing refs file says where it looked" '[ $rc != 0 ] && grep -q "$work/none" <<< "$err"'
run bogus;    check "an unknown command prints usage" '[ $rc = 2 ] && grep -q "secret get" <<< "$err"'

echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
