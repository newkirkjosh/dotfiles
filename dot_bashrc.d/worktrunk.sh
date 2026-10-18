# ─── Worktrunk (wt) shell integration ─────────────────────────────────
# Lets `wt switch` change this shell's directory. Loaded on the host (brew)
# and in arch-dev (pacman); a no-op where wt isn't installed.
if command -v wt >/dev/null 2>&1; then
  eval "$(wt config shell init bash)"
fi
