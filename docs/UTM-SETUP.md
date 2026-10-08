# Arch Linux ARM in UTM on an Apple Silicon Mac

M4 and M5 Macs can't boot Linux directly yet (Asahi Linux supports up to M3),
so Arch runs in a virtual machine. It's native ARM, not emulated, and fast.
Put UTM in full screen and it becomes its own macOS Space, so a three-finger
swipe moves between macOS and Linux.

Budget: about 20 minutes for the base install, then 20 to 60 for
`arch-dotfiles`.

## 1. Install UTM

Download it from <https://mac.getutm.app> (free), or run
`brew install --cask utm`. Use UTM **5.x** if you can, because that's the
version where hardware graphics work in the guest (see step 7).

## 2. Download the Archboot ISO

Arch Linux ARM has no official installer ISO. Archboot provides one. From
<https://release.archboot.com/aarch64/latest/iso/>, take the file ending in
**`-aarch64-ARCH-aarch64.iso`**, not the `-latest-` or `-local-` variants.

## 3. Create the VM

In UTM, choose **Create a New Virtual Machine → Virtualize → Linux**, then:

| Setting | Value |
|---|---|
| Use Apple Virtualization | **off**. Leaving it off gives you QEMU, which is needed for the clipboard sharing and the GPU option. |
| Boot ISO image | the Archboot ISO |
| Memory | 16 GB if the Mac has 32 GB or more, otherwise 8 GB |
| CPU cores | 6 to 8 |
| Storage | 128 GB (it's a sparse file, so it only takes what's used) |
| Shared directory | optional: a Mac folder to see at `/mnt/share` |
| Name | anything, e.g. `arch` |

Before the first boot, open the VM's **Settings**:

- **Display**: emulated display card `virtio-gpu-gl-pci` (GPU supported).
  Turn **Retina mode** on if text looks too small later.
- **Sharing**: directory share mode **VirtFS** (if you picked a folder), and
  turn on clipboard sharing.
- **Sound**: leave the default (`intel-hda`).
- **Input**: optionally enable "Capture input automatically" when the VM is
  full screen, so macOS doesn't eat the Cmd key.

## 4. Base install

Start the VM. Archboot boots to a menu. Exit to a shell (or choose the
"launcher → exit" option). Networking is already up in a UTM VM. Then run:

```sh
curl -fsSL https://raw.githubusercontent.com/cartermccann/arch-dotfiles/main/vm/install-arch-arm.sh -o i.sh
bash i.sh
```

It asks for a username, hostname and timezone (e.g. `America/Denver`), then
wipes the VM's virtual disk. Only the VM's disk is touched, never the Mac's.
It installs a minimal Arch Linux ARM with systemd-boot, NetworkManager and
your user with sudo. At the end it asks for your password.

Then:

1. `poweroff`
2. UTM → VM Settings → Drives → select the ISO drive → **Clear** (or delete it)
3. Start the VM again and log in at the text console.

## 5. Install arch-dotfiles

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/cartermccann/arch-dotfiles/main/bootstrap.sh)
```

It asks for your sudo password once, and your git name/email near the end.
Some AUR packages (Ghostty, a few tools) compile from source on ARM, which
is the slow part. When it finishes, run `sudo reboot`.

## 6. First login

Ly (the login screen) shows a slow blue colour wash. Pick **Hyprland** with
the arrow keys if it isn't already selected, type your password, and you're
in.

**Keyboard inside the VM:** macOS keeps the Cmd key for itself, so this
setup swaps the keys. **Option acts as Super**, and **Cmd acts as Alt**.
Option+Return opens a terminal, Option+Space the app launcher, and Option+/
lists every key.

## 7. Graphics: software vs GPU

The VM starts in **software rendering**. That always works, but the glass
blur and shadows are off and it uses more CPU. To try hardware graphics:

```sh
ouranos-gpu --on     # then log out (Option+Shift+E) and back in
```

If windows come up **black**, your UTM version can't do it yet. Switch back
from a terminal (Option+Return) or a text console (Ctrl+Alt+F1):

```sh
ouranos-gpu --off
```

`ouranos-gpu` with no arguments shows what's active.

## 8. Clipboard and shared folder

- **Clipboard:** text copied on the Mac pastes in Linux and vice versa (text
  only). It works when the VM runs in a window (not headless) with clipboard
  sharing on. A small agent, `ouranos-vdagent`, bridges UTM's SPICE
  clipboard to Wayland.
- **Shared folder:** if you picked one in step 3, it mounts at `/mnt/share`
  the first time you open it.

## Known limits

- **One display.** Change the resolution in UTM's display settings, not live
  inside Linux; changing the mode at runtime can white out the screen.
- **Video playback** is CPU-only. YouTube is fine; 4K isn't.
- **No native ARM build:** Slack, Spotify, Beeper, TIDAL and Bruno open as
  Chrome web apps. Cursor and Obsidian install as their official ARM
  AppImages, and Ghostty as the community AppImage build
  (pkgforge-dev/ghostty-appimage). You can always use the macOS versions on
  the Mac side.
- **Not installed on ARM:** OBS and Pinta (no aarch64 builds). The install
  summary lists anything else it had to skip.
