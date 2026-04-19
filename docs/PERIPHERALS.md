# Peripherals

Linux support status and setup for the current hardware.

## Logitech G502 X Lightspeed (mouse)

**Fully supported** via `libratbag` (daemon) + `piper` (GUI). Both are in the pacman package list.

- Device file: `logitech-g502-x-wireless.device` in libratbag's device DB
- USB ID: `046d:c098`
- Driver: `hidpp20`

### Setup

1. Plug in the Lightspeed dongle (USB-A on the desk).
2. Launch Piper:
   ```sh
   piper
   ```
3. Configure DPI stages, button bindings, polling rate, LED colors as desired.

### Notes

- G-Hub has no Linux port. Piper is the closest equivalent.
- `solaar` is a different tool — it handles *Unifying* receivers (MX Master etc.), not Lightspeed. Don't install it for the G502X.

## Logitech G533 (wireless headset)

**Works as a plain USB audio device out of the box.** For battery readout, sidetone, and notification sounds, use `headsetcontrol` (in the AUR list).

### Setup

1. Plug in the G533 dongle.
2. The headset shows up in PipeWire immediately. Default sink/source.
3. For battery and sidetone:
   ```sh
   headsetcontrol -b          # battery %
   headsetcontrol -s 64       # sidetone 0–128
   headsetcontrol -n 1        # notification beep
   ```

### Known limitations (per HeadsetControl compat table)

Supported features on the G533: sidetone, battery, notification sound.
**Not supported:** LED control, inactive timeout, chat mix, voice prompts, rotate-to-mute, EQ.

## Logitech C922 Pro Stream (webcam)

**Plug and play.** The Linux kernel's `uvcvideo` driver supports all UVC webcams including the C922. No setup.

### Verify

```sh
ls /dev/video*             # should show /dev/video0 and /dev/video1
v4l2-ctl --list-devices    # named listing (from v4l-utils)
```

Tools if you want controls / testing:

```sh
pacman -S v4l-utils guvcview   # control panel + test viewer
```

OBS and Discord pick it up automatically.

## Blue Yeti (USB microphone)

**Plug and play.** USB Audio Class device — handled by the kernel's generic USB audio driver. PipeWire recognizes it as a stereo input source.

### Verify

```sh
pactl list sources short | grep -i yeti
```

Set as default in `pavucontrol` if needed. No extra packages required.

### Gain / pattern / mute

All controlled via the hardware knobs on the Yeti itself. No Linux software needed (and Blue's Sherpa app is Windows/Mac only — not a loss).

## Udev — one-time group membership

If Piper or HeadsetControl ever reports permission errors on the HID device, add yourself to `input`:

```sh
sudo usermod -aG input $USER
```

Log out / back in. Most modern Arch setups don't require this — HID devices are accessible via seat-local ACLs — but it's the first thing to try if CLI tools fail with permission errors.
