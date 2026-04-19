# Android + KMP development

Goal: continue Kotlin Multiplatform work (Android + shared + JVM) on Arch.

## Toolchain

| Tool | Install | Purpose |
|------|---------|---------|
| JDK | `mise use -g java@21` | Android/KMP compile target |
| Android Studio | `android-studio` (AUR) | IDE + emulator + SDK manager |
| Android SDK | Installed via Android Studio SDK Manager | Platform tools, build-tools, NDK |
| Kotlin Native (Konan) | Pulled automatically by Gradle on first iOS/native build | KMP iOS artifact compilation |

JDK is managed by `mise`, not SDKMAN — single tool for Java, Node, Go, Python.

## Setup

1. Install Android Studio via AUR (handled by `packages.yaml`):
   ```sh
   yay -S android-studio
   ```
2. Open Android Studio → SDK Manager → install target platforms and build-tools.
3. Set `ANDROID_HOME`:
   ```sh
   # ~/.zshrc fragment (or source from ~/.secrets if machine-specific)
   export ANDROID_HOME="$HOME/Android/Sdk"
   export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"
   ```
4. KVM for emulator acceleration:
   ```sh
   sudo pacman -S qemu-base libvirt
   sudo usermod -aG kvm,libvirt $USER
   ```
   Reboot, then verify: `ls -l /dev/kvm` should show your user in the group.

## Gradle + KMP

- Gradle wrapper lives per-project — no global install needed.
- Konan caches go to `~/.konan` — large (several GB); exclude from any home-dir backups.
- If KMP iOS targets are needed, cross-compilation from Linux to iOS is **not supported** — keep a Mac in the loop for iOS builds.

## Physical device debugging

1. Install udev rules:
   ```sh
   sudo pacman -S android-udev
   ```
2. Add user to the `adbusers` group:
   ```sh
   sudo usermod -aG adbusers $USER
   ```
3. `adb devices` should now list a connected device after enabling USB debugging.

## Known gotchas

- Android Studio sometimes trips over Wayland — if plugins or dialogs render wrong, launch with `_JAVA_AWT_WM_NONREPARENTING=1` or `-Dawt.toolkit.name=WLToolkit` (experimental).
- KMP Gradle sync on a fresh machine pulls ~3–5 GB into `~/.gradle` and `~/.konan`. Plan storage accordingly.

## References

- [KMP setup guide](https://kotlinlang.org/docs/multiplatform-setup.html)
- [Android Studio on Arch](https://wiki.archlinux.org/title/Android)
- [mise docs](https://mise.jdx.dev)
