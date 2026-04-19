#!/usr/bin/env bash
# Bootstrap installer for dotfiles.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/newkirkjosh/dotfiles/main/install.sh | sh -s -- [profile]
#
# If no profile is passed, auto-detects via hyprctl + battery presence.

set -euo pipefail

DOTFILES_REPO="newkirkjosh/dotfiles"

# ─── Profile detection ───────────────────────────────────────────────
if [ -n "${1:-}" ]; then
    PROFILE="$1"
elif command -v hyprctl >/dev/null 2>&1; then
    if ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
        PROFILE="laptop"
    else
        PROFILE="desktop"
    fi
else
    PROFILE="desktop"
fi

# ─── Colors ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; RESET='\033[0m'
step()    { printf "${BLUE}→${RESET} %s\n" "$1"; }
success() { printf "${GREEN}✓${RESET} %s\n" "$1"; }
warn()    { printf "${YELLOW}⚠${RESET} %s\n" "$1"; }
fail()    { printf "${RED}✗${RESET} %s\n" "$1" >&2; exit 1; }

step "Profile: $PROFILE"

# ─── Sanity ──────────────────────────────────────────────────────────
if ! command -v pacman >/dev/null 2>&1; then
    fail "pacman not found — this installer is Arch-only"
fi

# ─── Enable multilib (required for Steam + 32-bit libs) ─────────────
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    step "Enabling [multilib] in /etc/pacman.conf"
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    sudo pacman -Syy --noconfirm
else
    success "multilib already enabled"
fi

# ─── Prereqs ─────────────────────────────────────────────────────────
step "Installing prerequisites (git, chezmoi, mise)"
sudo pacman -Sy --needed --noconfirm git chezmoi base-devel

# mise (via official installer — not in pacman repos)
if ! command -v mise >/dev/null 2>&1; then
    step "Installing mise"
    curl -fsSL https://mise.run | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

# ─── AUR helper (yay) ────────────────────────────────────────────────
if ! command -v yay >/dev/null 2>&1; then
    step "Installing yay (AUR helper)"
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
fi

# ─── chezmoi init + apply ────────────────────────────────────────────
step "Initializing chezmoi from $DOTFILES_REPO"
chezmoi init --apply --source-path "$HOME/.local/share/chezmoi" "$DOTFILES_REPO"

success "Bootstrap complete."
echo
echo "Next steps:"
echo "  1. Sign in to 1Password and enable the SSH agent (see docs/1PASSWORD.md)"
echo "  2. Run: chezmoi apply    (after any edits)"
echo "  3. Reboot into Hyprland via greetd"
