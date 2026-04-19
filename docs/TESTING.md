# Testing the install

Pre-flight checks to run **before** wiping a machine to install Arch. Catches the boring stuff — typos, missing packages, broken templates — so it doesn't blow up mid-install.

## What this catches

- Misnamed pacman / AUR packages
- Syntax errors in `install.sh` or `.chezmoiscripts/`
- Broken chezmoi templates
- Obvious YAML errors in `packages.yaml`

## What this does NOT catch

Testing the list below requires real hardware (or a heavyweight GPU-passthrough VM):

- Hyprland actually running + rendering
- NVIDIA Wayland behavior
- Steam / Proton / game compatibility
- Peripherals (G502X, G533, webcam, mic)
- greetd login flow, PipeWire audio, udev rules

See **Going deeper** at the bottom for options.

## Tier 1 — Docker smoke test

Requires Docker (or `alias docker=podman`). Run from the repo root.

### 1. Verify every pacman package exists

```sh
docker run --rm -v "$PWD:/repo" archlinux:latest bash -c '
  pacman -Sy --noconfirm >/dev/null 2>&1
  # Enable multilib so 32-bit packages (lib32-*) resolve
  sed -i "/^#\[multilib\]/,/^#Include/ s/^#//" /etc/pacman.conf
  pacman -Sy --noconfirm >/dev/null 2>&1
  pacman -S --noconfirm --needed yq >/dev/null 2>&1

  fail=0
  echo "→ pacman packages"
  for p in $(yq ".arch.pacman[]" /repo/.chezmoidata/packages.yaml); do
    pacman -Si "$p" >/dev/null 2>&1 && echo "  ✓ $p" || { echo "  ✗ $p  MISSING"; fail=1; }
  done
  echo "→ gpu_packages.nvidia"
  for p in $(yq ".arch.gpu_packages.nvidia[]" /repo/.chezmoidata/packages.yaml); do
    pacman -Si "$p" >/dev/null 2>&1 && echo "  ✓ $p" || { echo "  ✗ $p  MISSING"; fail=1; }
  done
  exit $fail
'
```

Exit code is non-zero if anything's missing.

### 2. Verify every AUR package exists

No container needed — uses the AUR RPC API.

```sh
for p in $(yq '.arch.aur[]' .chezmoidata/packages.yaml); do
  count=$(curl -sf "https://aur.archlinux.org/rpc/v5/info?arg%5B%5D=$p" | yq '.resultcount')
  [ "$count" = "1" ] && echo "  ✓ $p" || echo "  ✗ $p  NOT ON AUR"
done
```

### 3. Syntax-check shell scripts

```sh
bash -n install.sh && echo "  ✓ install.sh"
for f in .chezmoiscripts/*.sh.tmpl; do
  # Strip chezmoi template markers before bash -n
  sed 's/{{[^}]*}}//g' "$f" | bash -n - && echo "  ✓ $f" || echo "  ✗ $f"
done
```

### 4. Render chezmoi templates

Requires `chezmoi` locally (`brew install chezmoi` on WSL, `pacman -S chezmoi` on Arch).

```sh
for f in *.tmpl dot_*.tmpl .chezmoiscripts/*.tmpl; do
  [ -f "$f" ] || continue
  chezmoi execute-template \
    --init --promptString name=test \
    --promptString email=test@test \
    --promptString profile=desktop \
    --promptString signingkey= \
    < "$f" >/dev/null 2>&1 \
    && echo "  ✓ $f" || echo "  ✗ $f"
done
```

### One-liner: run all four

Save as `tests/smoke.sh` in the repo if you end up running it often. For now, bash-execute each block above in order.

## Going deeper

### Tier 2 — QEMU/KVM VM with Arch ISO

Useful if you want to rehearse the full install end-to-end in a throwaway environment.

- Install Arch manually or via `archinstall` inside the VM.
- Clone the repo, run `install.sh desktop`, watch it go.
- **Don't try to evaluate Hyprland or gaming** from the VM — software-rendered Wayland is not representative of real performance.
- Tests: install script flow, multilib enablement, pacman/AUR install, chezmoi apply, greetd config (might not actually start the session, but config generation verifies).

Rough setup on Arch host:

```sh
sudo pacman -S qemu-full virt-manager
sudo systemctl enable --now libvirtd
# GUI: virt-manager → new VM → Arch ISO → allocate 8 GB RAM / 40 GB disk / virtio-gpu
```

On WSL2 host, nested virt is possible but painful — Tier 2 is easier to run from a Linux box you already have.

### Tier 3 — Real hardware

The only way to test Hyprland performance, GPU drivers, Steam, and peripherals. Options:

1. **Spare SSD.** Install on a cheap SATA or NVMe, swap into the box, test, swap back. Current Windows drive is untouched.
2. **Dual-boot the target machine** when committing to the switch. Iterate in place on Arch until comfortable, then reclaim the Windows partition.
3. **USB live boot + `archinstall`.** Zero hardware cost, slower iteration.

Document every gotcha you hit in `docs/MIGRATION.md` as you go — future-you on the next machine pays the bill otherwise.

## When to run what

| When | Tier |
|------|------|
| After editing `packages.yaml` or any `.sh.tmpl` | Tier 1 |
| Before tagging a release / big push | Tier 1 full |
| Before installing on a new box | Tier 1, optionally Tier 2 |
| To actually validate the desktop / games work | Tier 3 — no substitute |
