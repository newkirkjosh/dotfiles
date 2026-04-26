# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What This Repo Is

A personal **Bazzite** workstation setup managed with [chezmoi](https://chezmoi.io). Bazzite is the host (KDE Plasma + immutable Fedora Atomic); all Arch userland and dev work happens inside an `arch-dev` distrobox container. Targets KMP / Android / Go / Node / Python development.

**Hard rule: no credentials anywhere.** No API keys, tokens, SSH keys, passwords. Secrets come from 1Password at apply-time or from a `~/.secrets` file that is git-ignored. Use `<PLACEHOLDER>` convention for anything that varies per machine.

## Install hierarchy (where things live, in order of preference)

| Layer | Use for |
|---|---|
| **`bazzite.distrobox`** (pacman + AUR inside arch-dev) | All dev tools, CLIs, language runtimes, dev GUIs (Android Studio, Ghostty) — exported to host launcher when GUI |
| **`bazzite.brew`** | Host-side CLIs that chezmoi or non-dev workflows need (chezmoi, gh, 1password-cli) |
| **`bazzite.flatpak`** | Host GUI apps that aren't dev tools (browser, chat, media) |
| **`bazzite.rpm_ostree`** | Reserved for kernel-adjacent / native-messaging things only (currently: 1password) — costs a reboot |
| **`bazzite.ujust`** | Bazzite's curated post-install one-liners |

When in doubt, prefer the topmost layer that works. The immutable host stays clean; the distrobox is where you experiment.

## Structure

| Path | Purpose |
|------|---------|
| `.chezmoi.toml.tmpl` | chezmoi init prompts (name, email, signing key) |
| `.chezmoidata/packages.yaml` | Declarative package lists for all install layers above |
| `.chezmoiscripts/` | `run_onchange_*` idempotent setup scripts (rpm-ostree before; brew/flatpak/ujust/distrobox/mise after) |
| `dot_config/` | Contents of `~/.config` (chezmoi's `dot_` = leading dot) |
| `dot_bashrc.d/` | Drop-in shell snippets sourced by `~/.bashrc` |
| `dot_zshrc.tmpl` | `~/.zshrc`, shared host+container; guards (`command -v`) make it boot cleanly in both |
| `install.sh` | Bootstrap entrypoint — `curl ... \| bash` |
| `docs/` | Setup notes: `BAZZITE.md`, `1PASSWORD.md`, `ANDROID.md`, `PERIPHERALS.md`, `FONTS.md` |

## Conventions

- **chezmoi naming:** `dot_foo` → `~/.foo`, `dot_config/bar` → `~/.config/bar`, `.tmpl` suffix = Go-templated file, `run_onchange_*.sh.tmpl` = idempotent script that reruns only when its hash changes.
- **Packages are declarative.** Add the package to `packages.yaml` under the right layer, run `chezmoi apply`. The install scripts pick it up.
- **Keep docs in `docs/`.** `CLAUDE.md`, `README.md`, `docs/`, and `install.sh` are all chezmoi-ignored — they live in the repo, not in `$HOME`.
- **Bazzite quirks worth remembering:**
  - `/usr/bin` is read-only — never assume a host path that requires writing there
  - `$HOME` is `/home/$USER` but mise + some tools resolve via `/var/home/$USER`; trust both prefixes (see `MISE_TRUSTED_CONFIG_PATHS` in `dot_zshrc.tmpl`)
  - `gh` lives in brew, not `/usr/bin/gh` — gitconfig credential helpers are gated off on Bazzite; SSH remotes via 1Password agent are the auth path

## Adding a package

1. Edit `.chezmoidata/packages.yaml` — pick the layer per the hierarchy above
2. Run `chezmoi diff` to preview, then `chezmoi apply`
3. If the app needs config, add to `dot_config/<app>/`
4. If it's a GUI from inside the container, add to `bazzite.distrobox.export_apps` so it appears in the host launcher

## What NOT to add

- Bazzite-native / obvious setup (the [Bazzite docs](https://docs.bazzite.gg) and `ujust --list` are authoritative)
- Anything Arch-native that won't be inside the container — there is no Arch host
- Credentials, SSH keys, tokens — 1Password or `~/.secrets` (git-ignored) only
