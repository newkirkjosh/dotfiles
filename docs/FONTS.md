# Fonts

Primary font: **JetBrains Mono NL Nerd Font**. "NL" = no ligatures variant.

## Install

Handled by `packages.yaml`:

```
ttf-jetbrains-mono-nerd   # all JetBrains Mono Nerd variants (NL, regular, propo)
```

The Nerd Font version bundles the glyphs that Starship and Waybar icons depend on (git status symbols, language icons, power icons, etc.).

## Verify

```sh
fc-list | grep -i jetbrains
# Should show multiple weights + NL variants
```

## Which variant to select in apps

The package installs several variants. Pick by name:

| Variant | Name string | Use |
|---------|-------------|-----|
| Regular | `JetBrainsMono Nerd Font` | With ligatures — general purpose |
| NL | `JetBrainsMono NL Nerd Font` | No ligatures — default for code/terminals |
| Mono | `JetBrainsMono Nerd Font Mono` | Strict monospace width for all glyphs |
| Propo | `JetBrainsMono Nerd Font Propo` | Proportional (rarely used) |

This repo uses **`JetBrainsMono Nerd Font`** in Ghostty and Waybar configs. Change to `... NL ...` if ligatures ever annoy you — purely a personal preference.

## Fallback fonts

For broad coverage (emoji, CJK):

- `noto-fonts` — main Noto family
- `noto-fonts-emoji` — color emoji
- `noto-fonts-cjk` — Chinese / Japanese / Korean

All three are in `packages.yaml`.

## Glyph test

```sh
echo -e "\ue0b0 \u00b1 \ue0a0 \u27a6 \u2718 \u26a1 \u2699 \uf1d3 \ue627"
```

If any character shows as `□`, the Nerd Font fallback isn't wired up — check the app's font setting and `fc-cache -fv`.

## References

- [JetBrains Mono](https://www.jetbrains.com/lp/mono/)
- [Nerd Fonts](https://www.nerdfonts.com/)
- [ArchWiki — Fonts](https://wiki.archlinux.org/title/Fonts)
