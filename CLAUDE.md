# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What This Repo Is

A personal Arch Linux workstation setup managed with [chezmoi](https://chezmoi.io). Target: a fresh Arch install running Hyprland, with full dev tooling for Kotlin Multiplatform, Android, Go, Node, and Python.

**Sister repo:** [homeprojects](https://github.com/newkirkjosh/homeprojects) covers the Proxmox homelab side. Keep workstation concerns here; server concerns there.

**Hard rule: no credentials anywhere.** No API keys, tokens, SSH keys, passwords. Secrets come from 1Password at apply-time or from a `~/.secrets` file that is git-ignored. Use `<PLACEHOLDER>` convention for anything that varies per machine.

## Structure

| Path | Purpose |
|------|---------|
| `.chezmoi.toml.tmpl` | chezmoi init prompts (name, email, profile, GPG key) |
| `.chezmoidata/packages.yaml` | Declarative package lists: `pacman`, `aur`, `flatpak` |
| `.chezmoiscripts/` | `run_onchange_after_*.sh.tmpl` idempotent setup scripts |
| `dot_config/` | Contents of `~/.config` (chezmoi's `dot_` = leading dot) |
| `dot_zshrc.tmpl` | `~/.zshrc`, templated for per-machine branches |
| `install.sh` | Bootstrap entrypoint (`curl | sh -s -- <profile>`) |
| `profiles.yaml` | Profile definitions (`desktop`, `laptop`) |
| `docs/` | Setup notes — read these before touching related configs |

## Conventions

- **chezmoi naming:** `dot_foo` → `~/.foo`, `dot_config/bar` → `~/.config/bar`, `.tmpl` suffix = Go-templated file, `run_onchange_after_*.sh.tmpl` = idempotent script that reruns only when its hash changes.
- **Packages are declarative.** To add an app, edit `.chezmoidata/packages.yaml`, not a script. The `run_onchange_after_install-*-packages.sh.tmpl` scripts pick it up on the next `chezmoi apply`.
- **Prefer pacman > AUR > flatpak** in that order. Document the reason if using flatpak for something that exists in AUR.
- **Keep docs in `docs/`.** `CLAUDE.md`, `README.md`, and `docs/` are all chezmoi-ignored (see `.chezmoiignore`) — they never get applied to the home directory.

## Adding a package

1. Edit `.chezmoidata/packages.yaml` — add under `arch.pacman`, `arch.aur`, or `flatpak`
2. Run `chezmoi apply` (or `chezmoi diff` first)
3. If the app needs config, add to `dot_config/<app>/`

## Adding a new profile

1. Define in `profiles.yaml`
2. Update `install.sh` auto-detect logic if needed
3. Add profile-gated branches in templates using `{{ if eq .profile "name" }}`

## What NOT to add

- Arch-native / obvious setup (pacman install basics, systemd unit enabling for common services) — the ArchWiki is authoritative
- Anything homelab/server-related — those live in the `homeprojects` repo
- Credentials, SSH keys, tokens — 1Password or `~/.secrets` (git-ignored) only
