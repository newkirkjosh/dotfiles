# Android + KMP development

Goal: Kotlin Multiplatform work (Android + shared + JVM) on Bazzite.

Everything Android lives **inside the `arch-dev` distrobox** — Android Studio is installed via AUR in the container and exported to the host launcher via `distrobox-export`. Click Android Studio in the KDE menu → it runs inside the container with the right toolchain already in `$PATH`.

## Toolchain

| Tool | Install | Purpose |
|------|---------|---------|
| JDK | `mise use -g java@21` (in container) | Android/KMP compile target |
| Android Studio | `android-studio` (AUR, in `bazzite.distrobox.aur`) | IDE + emulator + SDK manager |
| Android SDK | Installed via Android Studio SDK Manager | Platform tools, build-tools, NDK |
| Kotlin Native (Konan) | Pulled automatically by Gradle on first iOS/native build | KMP iOS artifact compilation |

JDK is managed by `mise`, not SDKMAN — single tool for Java, Node, Go, Python.

## Setup

1. After `chezmoi apply`, Android Studio is already installed in the container and visible in the host launcher.
2. Launch it. SDK Manager → install target platforms and build-tools.
3. `ANDROID_HOME` should resolve to `$HOME/Android/Sdk` (shared HOME between host and container, so the SDK installs to a path both can see).
4. KVM for emulator acceleration is provided by Bazzite's host kernel — verify inside the container:
   ```sh
   ls -l /dev/kvm
   ```
   Should be accessible (distrobox passes `/dev/kvm` through). If not, your user needs to be in the `kvm` group on the host: `sudo usermod -aG kvm $USER && reboot`.

## Gradle + KMP

- Gradle wrapper lives per-project — no global install needed.
- Konan caches go to `~/.konan` — large (several GB); exclude from any home-dir backups.
- KMP iOS targets are **not supported** from Linux — keep a Mac in the loop for iOS builds.

## Physical device debugging

`udev` rules need to be on the **host** (the kernel sees the USB device), not the container. On Bazzite, `android-udev` isn't directly layerable; the simplest route is to drop a rules file:

```sh
# On the host
sudo curl -o /etc/udev/rules.d/51-android.rules \
    https://raw.githubusercontent.com/M0Rf30/android-udev-rules/master/51-android.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
```

Then inside the container, `adb devices` should list the device after enabling USB debugging on the phone.

## Known gotchas

- Android Studio under KDE Wayland: if plugins or dialogs render wrong, launch with `_JAVA_AWT_WM_NONREPARENTING=1`.
- KMP Gradle sync on a fresh machine pulls ~3–5 GB into `~/.gradle` and `~/.konan`. Plan storage accordingly.
- The arch-dev container shares `$HOME` with the host, so `~/.gradle`, `~/.konan`, and `~/Android` are all visible from both sides.

## References

- [KMP setup guide](https://kotlinlang.org/docs/multiplatform-setup.html)
- [mise docs](https://mise.jdx.dev)
- [distrobox-export](https://distrobox.it/usage/distrobox-export/)
