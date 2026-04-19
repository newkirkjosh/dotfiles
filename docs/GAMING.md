# Gaming

Arch + Steam + Proton covers the large majority of modern PC gaming. This doc covers what's installed, how to use it, and the known hard limits.

## What's installed

| Package | Purpose |
|---------|---------|
| `steam` | Valve's client (32-bit — requires `[multilib]` enabled, handled by `install.sh`) |
| `gamescope` | Valve's compositor — run games in a nested session for better scaling/HDR/tearing behavior, especially under Hyprland |
| `gamemode` + `lib32-gamemode` | Feral's per-game CPU governor / I/O priority tweaks. Use via `gamemoderun <cmd>` or as a launch wrapper |
| `mangohud` + `lib32-mangohud` + `goverlay` | FPS / CPU / GPU overlay. `goverlay` is the GUI config tool |
| `lutris` | Launcher for non-Steam games (Battle.net, Epic, Amazon) |
| `heroic-games-launcher-bin` | Dedicated Epic / GOG / Amazon Prime client (often smoother than Lutris for those) |
| `protonup-qt` | Manage Proton-GE (Glorious Eggroll) versions — community Proton fork with extra compatibility patches |
| `wine-staging` + `winetricks` | Plain Wine for ad-hoc Windows apps outside Steam |

## Steam launch options — patterns worth knowing

Right-click game → Properties → Launch Options.

| Option | Effect |
|--------|--------|
| `gamemoderun %command%` | Wrap with gamemoded |
| `mangohud %command%` | Overlay on |
| `gamescope -f -W 2560 -H 1440 -r 144 -- %command%` | Run in fullscreen Gamescope at native res, 144 Hz — fixes many scaling/VRR/cursor issues under Hyprland |
| `PROTON_USE_WINED3D=1 %command%` | Force WineD3D instead of DXVK (rare fix for specific titles) |
| `MANGOHUD=1 gamemoderun gamescope -f -- %command%` | Stack them |

Combine freely. The Gamescope wrapper is the most common fix when something renders weirdly on Hyprland.

## Proton-GE

Official Proton covers most games. When it doesn't, Proton-GE often does (media codec fixes, cutscene video support, EAC/BattlEye tweaks).

```sh
protonup-qt
```

Install latest `GE-Proton` → restart Steam → pick it in the game's Compatibility dropdown.

## Anti-cheat — what works vs. what doesn't

**The two authoritative sites:**
- [ProtonDB](https://www.protondb.com) — community Proton compatibility reports
- [Are We Anti-Cheat Yet?](https://areweanticheatyet.com) — multiplayer anti-cheat specifically

**Works on Linux:**
- Easy Anti-Cheat (EAC) — IF the developer enabled the Linux/Proton runtime. Many have.
- BattlEye — same condition.
- Most custom / game-specific anti-cheat (Psyonix for Rocket League, VAC, etc.)

**Does NOT work on Linux, ever (kernel-level):**
- Riot Vanguard — Valorant, League of Legends client
- Some EA anti-cheat — newer EA titles / sports games
- Some Call of Duty titles (Warzone, MW series)
- Fortnite (Epic chose not to enable Linux for EAC here)

**Your library status (verified 2026-04-19):**
- ARC Raiders — Running (EAC, Embark enabled Linux) ✓
- Slay the Spire 2 — Native Linux build ✓
- Super Battle Golf — ProtonDB Platinum ✓
- Rocket League — ProtonDB Platinum (812 reports) ✓

## StarCraft 2 via Battle.net

Battle.net isn't on Steam. Use Lutris:

```sh
lutris
# Sources → Search → "Battle.net" → install via community installer script
```

Once Battle.net is running, SC2 installs like normal. If Blizzard login hangs, the standard fix is switching the Battle.net app's renderer to D3D9 in Lutris' Wine config.

## NVIDIA on Wayland tweaks

If you're on an NVIDIA GPU:

- Driver 555+ with explicit sync solves most Wayland issues. Confirm `nvidia-utils` version with `pacman -Q nvidia-utils`.
- Add these env vars (in `~/.config/hypr/hyprland.conf` — already stubbed):
  ```
  env = LIBVA_DRIVER_NAME,nvidia
  env = __GLX_VENDOR_LIBRARY_NAME,nvidia
  env = NVD_BACKEND,direct
  ```
- For Gamescope under NVIDIA: `--backend sdl` sometimes helps.

## Controllers

- **Xbox wired / PS4 wired / PS5 wired** — plug in, works via kernel HID.
- **Xbox wireless** — needs `xone` (AUR) for the wireless adapter, or `xpadneo-dkms` for Bluetooth Xbox controllers.
- **8BitDo / generic** — usually plug-and-play.

Test: `jstest /dev/input/js0` or use `sdl2-jstest`.

## References

- [ProtonDB](https://www.protondb.com)
- [Are We Anti-Cheat Yet?](https://areweanticheatyet.com)
- [Lutris](https://lutris.net)
- [ArchWiki — Steam](https://wiki.archlinux.org/title/Steam)
- [ArchWiki — Gaming](https://wiki.archlinux.org/title/Gaming)
