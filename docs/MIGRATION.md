# Migration notes — coming from Windows + WSL2

Context: prior setup was Windows 11 + WSL2 Ubuntu 24.04 + Homebrew + SDKMAN. Moving to bare-metal Arch + Hyprland.

## What goes away

| WSL thing | Arch replacement |
|-----------|------------------|
| Homebrew (`/home/linuxbrew`) | `pacman` + `yay` (AUR) — manage via `packages.yaml` |
| SDKMAN (Java) | `mise` — also handles Node, Go, Python in one tool |
| `npiperelay` + `socat` SSH bridge | Native 1Password SSH agent (see `1PASSWORD.md`) |
| `op-ssh-sign-wsl.exe` for git signing | Linux `op-ssh-sign` binary from `1password` package |
| `/mnt/c/...` paths and `.aws` / `.azure` symlinks | Reconfigure in Linux: `aws configure`, `az login` |
| Windows Terminal + `wt` profile shell-init | Ghostty, single config (also synced with macOS work box) |
| VS Code on Windows bin + WSL remote | Native `visual-studio-code-bin` (AUR) or Cursor |
| Android Studio on Windows | Native `android-studio` (AUR) |
| `studio()` zsh function (calls studio64.exe via wslpath) | Plain `android-studio .` — no path translation needed |

## What stays the same

- zsh as the login shell
- tmux config (`~/.tmux.conf` → `~/.config/tmux/tmux.conf` per XDG)
- `~/developer/{work, personal, sandbox, bookend, docs}` layout
- git config (name, email, pull.rebase, commit.gpgsign) — signing path changes only
- Claude Code + `~/.claude/` configuration

## What's changing that wasn't forced by the OS

- **Prompt:** Powerlevel10k → **Starship**. One `starship.toml` works across shells and matches the Ghostty-on-Mac work setup.
- **Framework:** Oh My Zsh → **standalone zsh plugins** (`zsh-autosuggestions`, `zsh-syntax-highlighting`, `zsh-completions` — all via pacman). No framework, one less abstraction.
- **`.p10k.zsh`** (95 KB) is gone — config lives in `dot_config/starship.toml` (compact TOML).

## Things to migrate manually (not in this repo)

- `~/.secrets` — live secrets, not version-controlled
- `~/.ssh/config` — host aliases
- `~/.gnupg/` — only if using GPG (we're on SSH signing via 1P now)
- `~/developer/` contents — clone repos as needed; no bulk copy

## Sanity checks after bootstrap

```sh
# Shell
echo $SHELL                         # /usr/bin/zsh
starship --version                  # prompt installed
starship explain                    # prints resolved prompt modules

# Hyprland
hyprctl monitors
waybar --version

# Dev
mise current                        # Java 21, Node LTS, Go latest, Python 3.13
java --version
docker ps                           # daemon running (sudo systemctl enable --now docker)
gh auth status

# 1Password
ssh-add -l                          # lists keys
git log --show-signature -1         # signature verified
```

## First steps after reboot into Hyprland

1. Sign in to 1Password, enable SSH agent
2. `gh auth login` (uses 1P SSH key)
3. Clone homeprojects, dotfiles (already cloned via chezmoi, but the working dir is `~/.local/share/chezmoi`)
4. Run `mise install` to materialize the pinned versions
5. `chezmoi apply` to re-run any pending scripts
