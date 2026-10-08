# PHASE: hardware: VM guest tools, CPU microcode, GPU drivers, ~/.config/hypr/local.lua
LOCAL_D=$REPO_DIR/config/hypr/local.d
parts=(base)

if [ "$IS_VM" = 1 ]; then
  install_list "$REPO_DIR/packages/vm.list"
  parts+=(vm)
  # an aarch64 VM is, in practice, UTM on a Mac: swap Option/Cmd roles
  [ "$ARCH" = aarch64 ] && parts+=(mac)
  if [ "$CHECK" = 0 ]; then
    # spice-vdagentd only serves the agent of an "active session"; a session
    # started from Ly doesn't always qualify, so run it with -X (no session
    # integration). Our Wayland clipboard agent (ouranos-vdagent) then talks
    # to it; the stock spice-vdagent session agent is X11-only.
    printf '[Service]\nEnvironment=SPICE_VDAGENTD_EXTRA_ARGS=-X\n' > "$STATE_DIR/vdagentd.conf"
    install_root "$STATE_DIR/vdagentd.conf" /etc/systemd/system/spice-vdagentd.service.d/10-no-session.conf
    sudo_run systemctl daemon-reload
    # UTM "VirtFS" shared folder → /mnt/share, mounted on first access, and
    # boot never waits on it if sharing is off.
    if ! grep -q '^share /mnt/share 9p' /etc/fstab; then
      sudo_run mkdir -p /mnt/share
      if [ "$DRY_RUN" = 1 ]; then note "would add a 9p /mnt/share line to /etc/fstab"
      else
        echo 'share /mnt/share 9p trans=virtio,version=9p2000.L,rw,msize=512000,nofail,x-systemd.automount 0 0' \
          | sudo tee -a /etc/fstab >/dev/null
        ok "VirtFS share will mount at /mnt/share (UTM → Settings → Sharing)"
      fi
    fi
  fi
  # Nothing to enable: spice-vdagentd and qemu-guest-agent are static units
  # that udev starts when UTM's virtio ports appear.
elif [ "$ARCH" = x86_64 ]; then
  ucode=
  grep -q GenuineIntel /proc/cpuinfo && ucode=intel-ucode
  grep -q AuthenticAMD /proc/cpuinfo && ucode=amd-ucode
  gpu=$(lspci -nn 2>/dev/null | grep -Ei 'vga|3d|display')
  pkgs=(mesa vulkan-icd-loader ${ucode:+$ucode})
  # 32-bit halves only exist once multilib is enabled (phase 10 does that)
  multilib=0; grep -q '^\[multilib\]' /etc/pacman.conf && multilib=1
  if grep -qi nvidia <<<"$gpu"; then
    # nvidia-open for the stock `linux` kernel, the -dkms build for any other
    if pacman -Q linux >/dev/null 2>&1; then pkgs+=(nvidia-open); else pkgs+=(nvidia-open-dkms linux-headers); fi
    pkgs+=(nvidia-utils libva-nvidia-driver)
    [ $multilib = 1 ] && pkgs+=(lib32-nvidia-utils)
    parts+=(nvidia)
  fi
  # (mesa itself carries the VA-API drivers for AMD now)
  # whole words: "ati" is also inside "NVIDIA Corporation"
  grep -Eq '\b(AMD|ATI)\b|Radeon' <<<"$gpu" && pkgs+=(vulkan-radeon)
  grep -Eq '\bIntel\b' <<<"$gpu" && pkgs+=(vulkan-intel intel-media-driver)
  [ $multilib = 1 ] && pkgs+=(lib32-mesa)
  printf '%s\n' "${pkgs[@]}" > "$STATE_DIR/hardware.list"
  install_list "$STATE_DIR/hardware.list"
  [ -n "$ucode" ] && remember "CPU microcode ($ucode) installed: add it to your bootloader entry if your bootloader doesn't pick it up automatically"
else
  # aarch64 bare metal (Asahi, someday): the kernel/mesa come from that distro
  printf 'mesa\n' > "$STATE_DIR/hardware.list"
  install_list "$STATE_DIR/hardware.list"
fi
compgen -G "/sys/class/power_supply/BAT*" >/dev/null && parts+=(laptop)

# ~/.config/hypr/local.lua: written once from the templates, then it's yours.
for p in "${parts[@]}"; do cat "$LOCAL_D/$p.lua"; done > "$STATE_DIR/local.lua"
seed_copy "$STATE_DIR/local.lua" "$HOME/.config/hypr/local.lua"
ok "hyprland local.lua: ${parts[*]}"
