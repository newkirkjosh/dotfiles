#!/usr/bin/env bash
# Bootstrap installer for dotfiles.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/newkirkjosh/dotfiles/main/install.sh | sh -s -- [profile]
#
# Supported distros:
#   - Arch family:   arch, cachyos, endeavouros, manjaro
#   - Fedora Atomic: bazzite, fedora (uBlue variants with ujust)
#
# Profile is only meaningful on Arch. On Bazzite it's auto-derived from battery presence.

set -euo pipefail

DOTFILES_REPO="newkirkjosh/dotfiles"

# ─── Colors ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; RESET='\033[0m'
step()    { printf "${BLUE}→${RESET} %s\n" "$1"; }
success() { printf "${GREEN}✓${RESET} %s\n" "$1"; }
warn()    { printf "${YELLOW}⚠${RESET} %s\n" "$1"; }
fail()    { printf "${RED}✗${RESET} %s\n" "$1" >&2; exit 1; }

# ─── Distro detection ────────────────────────────────────────────────
DISTRO_ID=$(. /etc/os-release && echo "$ID")
case "$DISTRO_ID" in
    arch|cachyos|endeavouros|manjaro) DISTRO_FAMILY="arch" ;;
    bazzite|fedora)                   DISTRO_FAMILY="bazzite" ;;
    *) fail "Unsupported distro: $DISTRO_ID" ;;
esac
step "Distro: $DISTRO_ID (family: $DISTRO_FAMILY)"

# ─── Profile detection ───────────────────────────────────────────────
if [ -n "${1:-}" ]; then
    PROFILE="$1"
elif ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
    PROFILE="laptop"
else
    PROFILE="desktop"
fi
step "Profile: $PROFILE"

# ─── Per-family bootstrap ────────────────────────────────────────────
case "$DISTRO_FAMILY" in
    arch)
        # Enable multilib (required for Steam + 32-bit libs)
        if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
            step "Enabling [multilib] in /etc/pacman.conf"
            sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
            sudo pacman -Syy --noconfirm
        else
            success "multilib already enabled"
        fi

        step "Installing prerequisites (git, chezmoi, base-devel)"
        sudo pacman -Sy --needed --noconfirm git chezmoi base-devel

        if ! command -v mise >/dev/null 2>&1; then
            step "Installing mise"
            curl -fsSL https://mise.run | sh
            export PATH="$HOME/.local/bin:$PATH"
        fi

        if ! command -v yay >/dev/null 2>&1; then
            step "Installing yay (AUR helper)"
            tmp=$(mktemp -d)
            git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
            (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
            rm -rf "$tmp"
        fi
        ;;

    bazzite)
        # Flathub should already be enabled on Bazzite; guard anyway (user scope).
        if ! flatpak remotes --user 2>/dev/null | grep -q flathub; then
            step "Adding Flathub (user scope)"
            flatpak remote-add --user --if-not-exists flathub \
                https://flathub.org/repo/flathub.flatpakrepo
        fi

        # Homebrew — chezmoi and a minimal host CLI toolchain live here.
        if ! command -v brew >/dev/null 2>&1; then
            step "Installing Homebrew"
            NONINTERACTIVE=1 /bin/bash -c \
                "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            # shellcheck disable=SC1091
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        fi

        if ! command -v chezmoi >/dev/null 2>&1; then
            step "Installing chezmoi via brew"
            brew install chezmoi
        fi

        # distrobox ships with Bazzite — sanity check so setup-distrobox doesn't fail silently.
        command -v distrobox >/dev/null 2>&1 || \
            warn "distrobox not found — it should ship with Bazzite. Verify your image."
        ;;
esac

# ─── chezmoi init + apply ────────────────────────────────────────────
step "Initializing chezmoi from $DOTFILES_REPO"
chezmoi init --apply --source-path "$HOME/.local/share/chezmoi" "$DOTFILES_REPO"

success "Bootstrap complete."
echo
echo "Next steps:"
case "$DISTRO_FAMILY" in
    arch)
        echo "  1. Sign in to 1Password and enable the SSH agent (see docs/1PASSWORD.md)"
        echo "  2. Run: chezmoi apply    (after any edits)"
        echo "  3. Reboot into Hyprland via greetd"
        ;;
    bazzite)
        echo "  1. Sign in to 1Password (Flatpak) and enable SSH agent."
        echo "     Set agent socket path to ~/.1password/agent.sock (matches dotfiles)."
        echo "  2. Enter your dev env:  distrobox enter arch-dev"
        echo "  3. Configure Ghostty to auto-launch a distrobox-entered shell (docs/BAZZITE.md)"
        ;;
esac
