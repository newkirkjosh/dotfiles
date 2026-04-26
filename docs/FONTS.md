# Fonts

Primary font: **JetBrains Mono Nerd Font**.

## Install

Fonts live where they're rendered:

- **Container** (Ghostty, in-container CLIs): installed via `bazzite.distrobox.pacman` →
  `ttf-jetbrains-mono-nerd`, `noto-fonts`, `noto-fonts-emoji`, `noto-fonts-cjk` *(add to packages.yaml as needed — currently the container ships fonts via toolbx-arch base)*.
- **Host** (KDE, Konsole, system menus): Bazzite ships JetBrains Mono via the base image. Install extras via Flatpak or `~/.local/share/fonts` if you need them.

The Nerd Font version bundles the glyphs that Starship and other terminal UIs depend on (git status symbols, language icons, power icons, etc.).

> **Bazzite quirk:** fonts installed inside the container are isolated from host font lookup. Apps running on the host won't see container-installed fonts and vice versa. If you change Ghostty's font, the change applies to the in-container Ghostty (which is the one you launch from the menu).

## Verify

In container:
```sh
fc-list | grep -i jetbrains
```

## Which variant to select in apps

| Variant | Name string | Use |
|---------|-------------|-----|
| Regular | `JetBrainsMono Nerd Font` | With ligatures — general purpose |
| NL | `JetBrainsMono NL Nerd Font` | No ligatures |
| Mono | `JetBrainsMono Nerd Font Mono` | Strict monospace for all glyphs |
| Propo | `JetBrainsMono Nerd Font Propo` | Proportional (rarely used) |

This repo uses **`JetBrainsMono Nerd Font`** in the Ghostty config. Change to `... NL ...` if ligatures ever annoy you.

## Glyph test

```sh
echo -e "\ue0b0 \u00b1 \ue0a0 \u27a6 \u2718 \u26a1 \u2699 \uf1d3 \ue627"
```

If any character shows as `□`, the Nerd Font fallback isn't wired up. Check the app's font setting and run `fc-cache -fv` in whichever environment owns that app (host or container).

## References

- [JetBrains Mono](https://www.jetbrains.com/lp/mono/)
- [Nerd Fonts](https://www.nerdfonts.com/)
