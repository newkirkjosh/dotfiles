# Bazzite

Post-install configuration notes for the Bazzite variant of this dotfiles setup.
Run `install.sh` first (it's distro-aware — detects Bazzite and branches automatically),
then work through the checklist below.

## First-boot checklist

1. `brh list` — confirm the atomic rollback helper is ready
2. Sign in to **1Password** (Flatpak) → enable SSH agent → set socket path to `~/.1password/agent.sock`
3. `sudo systemctl enable --now ratbagd.service` — then launch **Piper** to bind the G502X
4. Configure **Ghostty** to auto-enter the `arch-dev` distrobox (see below)
5. Open a terminal, run `distrobox enter arch-dev`, confirm `mise`, `starship`, `tmux` are live
6. Set `git config --global gpg.ssh.program <path>` if you sign commits with 1Password
7. `ujust --list` — skim for anything else worth running (Nvidia extras, gamescope session, etc.)

The rest of this doc expands each item.

## 1Password (Flatpak)

### Nature of the Flathub package

`com.onepassword.OnePassword` is a manifest wrapper — it downloads the official
tarball from `downloads.1password.com` at install time with a pinned SHA-256.
The binary that runs is bit-identical to the .deb/.rpm 1Password publishes.
Upstream releases are auto-tracked via the manifest's `x-checker-data`.

### Setup

1. Launch 1Password. Sign in.
2. **Settings → Developer → Use the SSH agent** — toggle on.
3. **Settings → Developer → SSH agent socket path**: set to `$HOME/.1password/agent.sock`.
   Matches the `SSH_AUTH_SOCK` export already in `~/.zshrc`.
4. Verify — in any shell (host or distrobox):
   ```sh
   ssh-add -l
   ```
   Should list your 1Password-stored SSH keys.

### Commit signing

`op-ssh-sign` lives inside the Flatpak sandbox. Point git at it:

```sh
# Find the sandbox path
flatpak info --show-location com.onepassword.OnePassword
# Then point git at <location>/files/share/1Password/op-ssh-sign, e.g.:
git config --global gpg.format ssh
git config --global gpg.ssh.program ~/.local/share/flatpak/app/com.onepassword.OnePassword/current/active/files/share/1Password/op-ssh-sign
git config --global commit.gpgsign true
```

### "Potentially unsafe" permissions

The Flatpak manifest requests `--device=all`, `--share=network`, and
`--filesystem=xdg-download`. `--device=all` is the broad one — required for
USB/YubiKey/biometric support. Not a red flag, but worth knowing.

## Peripherals — ratbagd for Piper (G502X)

Piper is a Flatpak GUI; it talks to `ratbagd` running on the host. Bazzite
ships ratbagd but it may not auto-start.

```sh
systemctl status ratbagd.service
sudo systemctl enable --now ratbagd.service   # if not running
```

Launch Piper from the app launcher — the mouse should appear with DPI/buttons
configurable as normal.

## Ghostty → distrobox

Daily dev workflow lives inside `arch-dev`. Make Ghostty open there by default.

Edit `~/.config/ghostty/config`:

```
command = distrobox enter arch-dev
```

Every new Ghostty window lands inside the container. Escape hatch for a host
shell:

```sh
ghostty --command=/bin/zsh
```

If you want split behavior (host shell vs container shell on different keybinds),
see the Ghostty docs — the syntax for per-keybind commands is Ghostty-specific
and evolves across versions.

## Distrobox cheatsheet

```sh
distrobox enter arch-dev                           # shell inside container
distrobox enter arch-dev -- <command>              # run one-off inside
distrobox list                                     # list containers
distrobox rm arch-dev                              # destroy — chezmoi apply rebuilds it
distrobox enter arch-dev -- distrobox-export --app <name>   # surface GUI to host
distrobox enter arch-dev -- distrobox-export --bin <path>   # surface CLI binary to host
```

USB/HID devices (gamepads, headsets, YubiKey) and the GPU pass through
transparently — no extra config needed.

## Atomic rollback

When a system update breaks something (classic case: Nvidia driver regression):

```sh
brh list                   # see available previous images
brh rollback <target>      # roll back + reboot into that image
```

Previous images are retained for **90 days**. To keep one longer, pin its
deployment:

```sh
rpm-ostree status          # identify deployment index
sudo ostree admin pin <index>
```

## ujust helpers

`ujust` is Bazzite's curated menu of one-shot setup helpers. Safer than
`rpm-ostree install` for anything it covers.

```sh
ujust --list               # full menu
```

A few that are worth knowing about:

- `ujust update` — updates image + Flatpaks + brew in one shot
- `ujust install-nvidia-extras` — layers CUDA / NVENC bits for Nvidia GPUs
- Gaming-mode, gamescope session, and Decky loader helpers also exist; name
  varies across Bazzite versions so check `ujust --list` on your install

Only `install-nvidia-extras` is wired into `packages.yaml` (GPU-conditional).
Add others to `bazzite.ujust` if you want them applied declaratively.

## Flatseal (optional)

GUI for Flatpak permission tweaks. Useful for apps that need extra filesystem
access (Obsidian vaults outside `~`, Discord screenshare, etc.).

```sh
flatpak install --user -y flathub com.github.tchx84.Flatseal
```

Not in `packages.yaml` because it's optional — add there if you use it often.

## Flathub app installation notes

All Flatpaks in this repo install at `--user` scope (see
`.chezmoiscripts/run_onchange_after_install-flatpak-packages.sh.tmpl`). This
keeps them out of the system image so they survive rebases cleanly.
