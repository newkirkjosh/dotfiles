# ─── Distrobox / arch-dev shortcuts ──────────────────────────────────
alias arch="distrobox enter arch-dev"
alias a="distrobox enter arch-dev"
arx() { distrobox enter arch-dev -- "$@"; }
alias arch-up="distrobox enter arch-dev -- sudo pacman -Syu --noconfirm"
alias arch-aur="distrobox enter arch-dev -- yay -Syu --noconfirm"
alias arch-stop="distrobox stop arch-dev"
alias arch-rm="distrobox rm arch-dev"
alias arch-logs="distrobox enter arch-dev -- journalctl --user -n 50"
