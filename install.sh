#!/usr/bin/env bash
# Bootstrap installer for dotfiles on Bazzite (or Fedora Atomic uBlue variants).
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/newkirkjosh/dotfiles/main/install.sh | bash

set -euo pipefail

DOTFILES_REPO="newkirkjosh/dotfiles"

# ─── Colors ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; RESET='\033[0m'
step()    { printf "${BLUE}→${RESET} %s\n" "$1"; }
success() { printf "${GREEN}✓${RESET} %s\n" "$1"; }
warn()    { printf "${YELLOW}⚠${RESET} %s\n" "$1"; }
fail()    { printf "${RED}✗${RESET} %s\n" "$1" >&2; exit 1; }

# ─── Distro check ────────────────────────────────────────────────────
DISTRO_ID=$(. /etc/os-release && echo "$ID")
case "$DISTRO_ID" in
    bazzite|fedora) ;;
    *) fail "Unsupported distro: $DISTRO_ID. This dotfiles repo targets Bazzite / Fedora Atomic." ;;
esac
step "Distro: $DISTRO_ID"

# ─── Flathub (user scope) ────────────────────────────────────────────
if ! flatpak remotes --user 2>/dev/null | grep -q flathub; then
    step "Adding Flathub (user scope)"
    flatpak remote-add --user --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo
fi

# ─── Homebrew (host CLI escape valve) ────────────────────────────────
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

# distrobox ships with Bazzite — sanity check.
command -v distrobox >/dev/null 2>&1 || \
    warn "distrobox not found — it should ship with Bazzite. Verify your image."

# ─── chezmoi init + apply ────────────────────────────────────────────
step "Initializing chezmoi from $DOTFILES_REPO"
chezmoi init --apply --source-path "$HOME/.local/share/chezmoi" "$DOTFILES_REPO"

success "Bootstrap complete."
echo
echo "Next steps:"
echo "  1. Sign in to 1Password (rpm-ostree layered) and enable the SSH agent."
echo "     Confirm agent socket path is ~/.1password/agent.sock (matches dotfiles)."
echo "  2. Reboot if 1Password was newly layered."
echo "  3. Open Ghostty from the KDE app menu — drops you straight into arch-dev."
echo "  4. Inside the container: verify mise, starship, tmux, lazygit, btop are live."
