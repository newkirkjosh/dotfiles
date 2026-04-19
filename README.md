# dotfiles

Personal Arch Linux + Hyprland workstation setup, managed with [chezmoi](https://chezmoi.io).

Paired with the [homeprojects](https://github.com/newkirkj/homeprojects) repo — this one handles the workstation (Arch), that one handles the homelab (Proxmox).

## Bootstrap

On a fresh Arch install:

```sh
curl -sSL https://raw.githubusercontent.com/newkirkj/dotfiles/main/install.sh | sh -s -- desktop
```

The installer:
1. Installs `chezmoi` and `mise` if missing
2. Clones this repo into `~/.local/share/chezmoi`
3. Runs `chezmoi apply` — which installs packages, symlinks configs, and runs setup scripts

## Profiles

| Profile | Use |
|---------|-----|
| `desktop` | Full Hyprland workstation (default) |
| `laptop` | Desktop + laptop-specific tweaks (TBD) |

Auto-detected based on battery presence if no profile is passed.

## Structure

```
.chezmoi.toml.tmpl         — chezmoi init template (prompts for name, email, profile)
.chezmoidata/              — declarative data used by templates and scripts
  packages.yaml            — pacman / AUR / flatpak package lists
.chezmoiscripts/           — run_onchange_after_*.sh.tmpl setup scripts
dot_config/                — contents of ~/.config
dot_zshrc.tmpl             — ~/.zshrc (templated for per-machine bits)
install.sh                 — bootstrap entrypoint
profiles.yaml              — profile definitions
docs/                      — setup notes (Hyprland, Android, 1Password, fonts, migration)
```

## Conventions

- **No credentials in the repo.** Secrets come from 1Password at apply-time (or from a `~/.secrets` file that's git-ignored).
- Templates use chezmoi's Go-template syntax; per-machine or per-profile branches live in `.tmpl` files.
- Package lists are declarative — edit `packages.yaml`, run `chezmoi apply`, the install scripts handle the rest.

## Not included

- Anything that's native or obvious on Arch (pacman basics, systemd, kernel config) — defer to the [ArchWiki](https://wiki.archlinux.org).
- Server/homelab setup — see the [homeprojects](https://github.com/newkirkj/homeprojects) repo.
