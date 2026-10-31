# AGENTS.md

Guidance for agents working in this repository. `CLAUDE.md` only imports this file; review rules live in `REVIEW.md`.

## What This Repo Is

A personal **Bazzite** workstation setup managed with [chezmoi](https://chezmoi.io). Bazzite is the host (KDE Plasma + immutable Fedora Atomic); all Arch userland and dev work happens inside an `arch-dev` distrobox container. Targets KMP / Android / Go / Node / Python development.

**Hard rule: no credentials anywhere.** No API keys, tokens, SSH keys, passwords. Secrets come from 1Password at apply-time or from a `~/.secrets` file that is git-ignored. Use `<PLACEHOLDER>` convention for anything that varies per machine.

## Install hierarchy (where things live, in order of preference)

| Layer | Use for |
|---|---|
| **`bazzite.distrobox`** (pacman + AUR inside arch-dev) | All dev tools, CLIs, language runtimes, dev GUIs (Android Studio, Ghostty) — exported to host launcher when GUI |
| **`bazzite.brew`** | Host-side CLIs that chezmoi or non-dev workflows need (chezmoi, gh, 1password-cli) |
| **`bazzite.flatpak`** | Host GUI apps that aren't dev tools (browser, chat, media) |
| **`bazzite.device_packages`** | Flatpak apps gated on USB hardware detection — only installs when `lsusb` matches a USB ID |
| **`bazzite.rpm_ostree`** | Reserved for kernel-adjacent / native-messaging things only (currently: 1password) — costs a reboot |
| **`bazzite.ujust`** | Bazzite's curated post-install one-liners |

When in doubt, prefer the topmost layer that works. The immutable host stays clean; the distrobox is where you experiment.

## Structure

| Path | Purpose |
|------|---------|
| `.chezmoi.toml.tmpl` | chezmoi init prompts (name, email, signing key) |
| `.chezmoidata/bazzite.yaml` | Bazzite package lists: rpm_ostree, flatpak, device_packages, brew, ujust, distrobox |
| `.chezmoidata/mise.yaml` | mise language runtimes (shared across host and distrobox) |
| `.chezmoidata/claude.yaml` | Claude Code settings merged into `~/.claude/settings.json` on apply |
| `.chezmoiscripts/` | `run_onchange_*` idempotent scripts — see naming conventions below |
| `dot_claude/` | `~/.claude/` files (statusline script, etc.) |
| `dot_config/` | `~/.config/` files (systemd user services, ghostty, git, tmux, starship) |
| `dot_local/` | `~/.local/` files |
| `dot_zshrc.tmpl` | `~/.zshrc`, shared host+container; guards (`command -v`) make it boot cleanly in both |
| `dot_gitconfig.tmpl` | `~/.gitconfig`, templated for name/email/signing key |
| `test/validate.sh` | Validates templates and YAML locally — run before pushing |
| `.github/workflows/validate.yml` | CI: runs validate.sh on push/PR |
| `install.sh` | Bootstrap entrypoint — `curl ... \| bash` |
| `docs/` | Setup notes: `BAZZITE.md`, `1PASSWORD.md`, `ANDROID.md`, `PERIPHERALS.md`, `FONTS.md` |

## Conventions

### chezmoi naming

- `dot_foo` → `~/.foo`, `dot_config/bar` → `~/.config/bar`
- `.tmpl` suffix = Go-templated file
- `executable_` prefix = sets execute bit on the deployed file
- `run_onchange_*.sh.tmpl` = idempotent script that reruns only when its rendered content changes
- `run_before_` = runs before chezmoi applies file changes; `run_after_` (or `run_onchange_after_`) = runs after

### Script naming (`run_onchange_after_<verb>-<subject>.sh.tmpl`)

Use the verb that matches the action:

| Verb | Use for |
|---|---|
| `install` | Installing packages (flatpak, brew, pacman, npm, mise) |
| `setup` | Bootstrapping services, containers, or one-time system state |
| `configure` | Configuring existing system features (firewall, display, etc.) |
| `update` | Non-destructively merging managed config into an existing file |

### chezmoidata

Data lives in `.chezmoidata/*.yaml`. Chezmoi merges all files in that directory — keys are top-level so splitting files is transparent to scripts. Add new domains as new files rather than growing existing ones.

### Packages are declarative

Add the package to the right `.chezmoidata/` file under the appropriate layer key, then run `chezmoi apply`. The install scripts pick it up automatically (they re-run when the rendered template content changes).

For a device-conditional Flatpak, add an entry to `bazzite.device_packages` with `flatpak_id` and a list of `usb_ids` (lowercase hex `VVVV:PPPP` as shown by `lsusb`).

### Claude Code settings

Managed settings live in `.chezmoidata/claude.yaml` under two keys:
- `claude.settings` — merged into `~/.claude/settings.json` (our keys win on conflict)
- `claude.marketplace` — merged alongside settings (marketplace registrations)

`run_onchange_after_update-claude-settings.sh.tmpl` handles the merge on every apply. User-added top-level keys in `settings.json` are preserved. The `~/.claude/statusline-command.sh` script is deployed from `dot_claude/executable_statusline-command.sh`.

### Keep docs out of `$HOME`

The root `AGENTS.md`, `CLAUDE.md`, `REVIEW.md`, `README.md`, `docs/`, `install.sh`, `.github/**`, and `test/**` are all chezmoi-ignored — they live in the repo but are never applied to `$HOME`. A new root doc needs its own line in `.chezmoiignore`, or the next apply copies it into `$HOME`. The root ignores match the root target only, so they do **not** catch `dot_claude/CLAUDE.md`, which *is* applied to `~/.claude/CLAUDE.md` as the global Claude instructions.

## Tracker

GitHub issues on this repository.

## Layers

None: a change here is one PR, not a layered `dev` run.

## Pull requests

Conventional-commit titles. Labels: one of `enhancement`, `bug` or `documentation`. No project board. Squash merge only.

## Merge policy

An agent may squash-merge its own PR when every gate holds on the PR's head commit, re-checked right before merging: CI green, the Codex cross-review converged, every CodeRabbit comment fixed or answered, and no unresolved review thread. Hand the merge back to the user instead when the PR touches a guard or a secret path: `dot_config/git/hooks/` (privacy and secret scans), `dot_claude/hooks/` (the dangerous-git guard), `dot_local/bin/executable_secret` (the keyring helper), what configures or switches those on (`dot_gitconfig.tmpl`, which sets `core.hooksPath`; `.chezmoidata/claude.yaml` and `.chezmoiscripts/run_onchange_after_update-claude-settings.sh.tmpl`, which deploy Claude Code's permission denials and hook registrations), `.github/workflows/`, the review rules and what applies them (`REVIEW.md`, `.coderabbit.yaml`), or this Merge policy or the Code Review Rules section of this file.

## Code Review Rules

Read `REVIEW.md` at the repository root and apply it in full as the review rules for this repo. This section exists for Codex, which reads `AGENTS.md` but not `REVIEW.md`.

## Commits

Sign commits via 1Password's SSH agent. From the arch-dev distrobox use `git -c gpg.ssh.program=/run/host/usr/lib/opt/1Password/op-ssh-sign commit ...` (the gitconfig conditional handles host-side automatically). The `includeCoAuthoredBy: false` setting in `.chezmoidata/claude.yaml` suppresses Claude co-author trailers — no per-commit handling needed.

## Bazzite quirks worth remembering

- `/usr/bin` is read-only — never assume a host path that requires writing there
- `$HOME` is `/home/$USER` but mise + some tools resolve via `/var/home/$USER`; trust both prefixes (see `MISE_TRUSTED_CONFIG_PATHS` in `dot_zshrc.tmpl`)
- `gh` lives in brew, not `/usr/bin/gh` — gitconfig credential helpers are gated off on Bazzite; SSH remotes via 1Password agent are the auth path
- `op-ssh-sign` is at `/usr/lib/opt/1Password/op-ssh-sign` on Bazzite (not `/opt/1Password/` as on standard Linux). The gitconfig template uses a Bazzite conditional for this.
- When running chezmoi from inside the arch-dev distrobox, the host filesystem is at `/run/host/` — so `op-ssh-sign` is `/run/host/usr/lib/opt/1Password/op-ssh-sign` from that context.

## Adding a package

1. Open `.chezmoidata/bazzite.yaml` — pick the layer per the hierarchy above
2. Run `test/validate.sh` to catch template errors, then `chezmoi apply`
3. If the app needs config, add to `dot_config/<app>/`
4. If it's a GUI from inside the container, add to `bazzite.distrobox.export_apps` so it appears in the host launcher
5. If it's a Flatpak that should only install on specific hardware, use `bazzite.device_packages` instead of `bazzite.flatpak`

## What NOT to add

- Bazzite-native / obvious setup (the [Bazzite docs](https://docs.bazzite.gg) and `ujust --list` are authoritative)
- Anything Arch-native that won't be inside the container — there is no Arch host
- Credentials, SSH keys, tokens — 1Password or `~/.secrets` (git-ignored) only

This clone deliberately leaves `privacy.public` unset: the local private-terms list includes this repo's own machine-setup terms, so the global commit hook would block every commit. Check each diff against `REVIEW.md`'s privacy rule by hand. gitleaks runs on every commit where it is installed (the hook warns and lets a commit through when it is missing, so run `gitleaks git --staged` yourself before pushing from such a machine), and in CI on every push and PR.
