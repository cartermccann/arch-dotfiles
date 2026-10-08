#!/usr/bin/env bash
# Base Arch Linux ARM install for a fresh UTM VM, run from the Archboot ISO.
# docs/UTM-SETUP.md walks through creating the VM and getting here.
#
#   curl -fsSL https://raw.githubusercontent.com/cartermccann/arch-dotfiles/main/vm/install-arch-arm.sh -o i.sh
#   bash i.sh
#
# ERASES /dev/vda. Lays out GPT: 1 GiB EFI + btrfs root, installs base +
# linux-aarch64 with pacstrap, systemd-boot, NetworkManager, your user with
# sudo. After it finishes: shut down, remove the ISO in UTM, boot, log in,
# and run the arch-dotfiles one-liner.
#
# Adapted from Cua's install-arch.sh (trycua/cua, docs/public/scripts/
# omarchy-arm64-lume), MIT License, Copyright (c) 2025 Cua AI, Inc.
# (full text: THIRD_PARTY.md)
set -euo pipefail

disk=/dev/vda
target=/mnt

[ "$(uname -m)" = aarch64 ] || { echo "this is the aarch64 (Apple Silicon VM) installer"; exit 1; }
[ -b "$disk" ] || { echo "no $disk: in UTM, give the VM a VirtIO disk"; exit 1; }
[ -d /sys/firmware/efi ] || { echo "not booted in UEFI mode (UTM's QEMU aarch64 VMs are UEFI by default)"; exit 1; }

read -rp "username: " user
[[ $user =~ ^[a-z_][a-z0-9_-]*$ ]] || { echo "lowercase letters/digits only"; exit 1; }
read -rp "hostname [archvm]: " host; host=${host:-archvm}
read -rp "timezone, e.g. America/Denver [UTC]: " tz; tz=${tz:-UTC}
[ -e "/usr/share/zoneinfo/$tz" ] || { echo "unknown timezone: $tz (e.g. America/Denver)"; exit 1; }

echo
lsblk "$disk"
echo
read -rp "ALL DATA ON $disk WILL BE ERASED. Type ERASE to continue: " confirm
[ "$confirm" = ERASE ] || exit 1

sgdisk --zap-all "$disk"
sgdisk -n 1:1MiB:+1GiB -t 1:ef00 -c 1:EFI "$disk"
sgdisk -n 2:0:0 -t 2:8300 -c 2:ROOT "$disk"
partx -u "$disk"
udevadm settle

mkfs.fat -F 32 -n EFI "${disk}1"
mkfs.btrfs -f -L ARCH "${disk}2"
mount -o compress=zstd "${disk}2" "$target"
mkdir -p "$target/boot"
mount "${disk}1" "$target/boot"

# The ARM keyring goes in with the first pacstrap so the new system trusts
# its own packages without a separate bootstrap step.
pacstrap -K "$target" \
  base base-devel linux-aarch64 linux-firmware archlinuxarm-keyring \
  btrfs-progs dosfstools efibootmgr git networkmanager openssh sudo nano

genfstab -U "$target" >>"$target/etc/fstab"

arch-chroot "$target" /bin/bash -s -- "$tz" "$host" "$user" <<'CHROOT'
set -euo pipefail
tz=$1 host=$2 user=$3

ln -sf "/usr/share/zoneinfo/$tz" /etc/localtime
hwclock --systohc || true
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
printf 'LANG=en_US.UTF-8\n' >/etc/locale.conf
printf '%s\n' "$host" >/etc/hostname
printf '127.0.0.1 localhost\n::1 localhost\n127.0.1.1 %s.localdomain %s\n' "$host" "$host" >/etc/hosts

useradd -m -G wheel -s /bin/bash "$user"
# wheel may sudo (with your password)
printf '%%wheel ALL=(ALL:ALL) ALL\n' >/etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel

systemctl enable NetworkManager systemd-timesyncd

bootctl install
cat >/boot/loader/loader.conf <<'LOADER'
default arch.conf
timeout 2
console-mode keep
editor no
LOADER
root_uuid=$(blkid -s UUID -o value /dev/vda2)
cat >/boot/loader/entries/arch.conf <<ENTRY
title Arch Linux ARM
linux /Image
initrd /initramfs-linux.img
options root=UUID=$root_uuid rw rootwait rootflags=compress=zstd quiet
ENTRY
CHROOT

echo
echo "Set a password for $user:"
until arch-chroot "$target" passwd "$user"; do echo "try again"; done
umount -R "$target"
cat <<EOF

Base install done.
  1. poweroff
  2. In UTM: VM settings → Drives → remove (clear) the Archboot ISO
  3. Start the VM, log in as $user, then run:

     bash <(curl -fsSL https://raw.githubusercontent.com/cartermccann/arch-dotfiles/main/bootstrap.sh)
EOF
