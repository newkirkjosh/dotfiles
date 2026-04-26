# dotfiles

Personal Bazzite workstation setup, managed with [chezmoi](https://chezmoi.io). Host is KDE Plasma on immutable Fedora Atomic; all Arch userland and dev tooling lives inside an `arch-dev` distrobox container.

## Bootstrap

On a fresh Bazzite install:

```sh
curl -sSL https://raw.githubusercontent.com/newkirkjosh/dotfiles/main/install.sh | bash
```

The installer:
1. Adds Flathub (user scope) if missing
2. Installs Homebrew + chezmoi
3. Clones this repo into `~/.local/share/chezmoi`
4. Runs `chezmoi apply` — which lays packages, creates the `arch-dev` distrobox, installs everything inside it, and exports the GUI dev apps to the host launcher

Reboot once after install to activate the rpm-ostree-layered 1Password.

## Install layer hierarchy

| Layer | Use for |
|---|---|
| `bazzite.distrobox` (pacman + AUR) | Dev tools, language runtimes, dev GUIs (Ghostty, Android Studio) |
| `bazzite.brew` | Host CLIs (chezmoi, gh, 1password-cli) |
| `bazzite.flatpak` | Host GUI apps that aren't dev tools (Brave, Slack, Spotify, Obsidian) |
| `bazzite.rpm_ostree` | Kernel-adjacent / native-messaging only (1Password) |
| `bazzite.ujust` | Bazzite's curated post-install one-liners |

The immutable host stays minimal. Experimentation happens inside the container.

## Structure

```
.chezmoi.toml.tmpl         — chezmoi init template (prompts for name, email, signing key)
.chezmoidata/              — declarative data used by templates and scripts
  packages.yaml            — all install layers
.chezmoiscripts/           — run_onchange_* setup scripts (idempotent)
dot_config/                — contents of ~/.config
dot_bashrc.d/              — shell snippets sourced by ~/.bashrc (host)
dot_zshrc.tmpl             — ~/.zshrc, shared host + container with guards
install.sh                 — bootstrap entrypoint
docs/                      — setup notes (Bazzite, 1Password, Android, Peripherals, Fonts)
```

## Conventions

- **No credentials in the repo.** Secrets come from 1Password at apply-time (or from a `~/.secrets` file that's git-ignored).
- Templates use chezmoi's Go-template syntax; per-OS branches use `{{ if eq .chezmoi.osRelease.id "bazzite" }}`.
- Package lists are declarative — edit `packages.yaml`, run `chezmoi apply`, the install scripts handle the rest.
