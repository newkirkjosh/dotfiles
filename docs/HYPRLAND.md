# Hyprland

Notes for the Hyprland desktop setup. Config lives at `dot_config/hypr/hyprland.conf`.

## Components

| Piece | Package | Purpose |
|-------|---------|---------|
| Compositor | `hyprland` | Core Wayland compositor + tiling WM |
| Bar | `waybar` | Status bar |
| Launcher | `rofi` | App launcher (XWayland — larger plugin ecosystem than wofi; rofi-wayland fork is unmaintained) |
| Lock screen | `hyprlock` | Screen lock |
| Idle manager | `hypridle` | Triggers lock/DPMS on inactivity |
| Screenshot | `hyprshot` | Region / window / output capture |
| Clipboard manager | `cliphist` + `wl-clipboard` | History via rofi |
| Polkit agent | `polkit-kde-agent` | Auth prompts for sudo GUI actions |
| Portals | `xdg-desktop-portal-hyprland` + `-gtk` | File pickers, screen sharing |
| Login manager | `greetd` + `greetd-tuigreet` | TTY-based greeter → Hyprland |

## First-boot checklist

1. Run `install.sh` — installs all packages + configs.
2. Enable greetd:
   ```sh
   sudo systemctl enable greetd.service
   ```
3. Configure greetd to launch Hyprland — edit `/etc/greetd/config.toml`:
   ```toml
   [default_session]
   command = "tuigreet --time --cmd Hyprland"
   user = "greeter"
   ```
4. Reboot. Log in through greetd into Hyprland.
5. Open 1Password → Settings → Developer → enable SSH agent (see `1PASSWORD.md`).

## Default keybinds

See `dot_config/hypr/hyprland.conf` for the full list. Cheat-sheet:

| Keybind | Action |
|---------|--------|
| `SUPER + Return` | Ghostty terminal |
| `SUPER + B` | Brave |
| `SUPER + E` | Dolphin |
| `SUPER + D` | Rofi launcher |
| `SUPER + Q` | Kill focused window |
| `SUPER + L` | Lock (hyprlock) |
| `SUPER + H/J/K/L` | Focus left/down/up/right |
| `SUPER + 1–5` | Switch workspace |
| `SUPER + SHIFT + 1–5` | Move window to workspace |
| `Print` / `SHIFT+Print` / `CTRL+Print` | Screenshot region / window / output |

## Known TODOs

- Tune animations and blur to taste
- Wire hypridle to actually trigger hyprlock at X minutes
- Nvidia-specific env vars if running NVIDIA (see Hyprland wiki)
- Multi-monitor setup once hardware is known

## References

- [Hyprland Wiki](https://wiki.hyprland.org)
- [Hyprland on ArchWiki](https://wiki.archlinux.org/title/Hyprland)
- [greetd + tuigreet](https://man.sr.ht/~kennylevinsen/greetd/)
