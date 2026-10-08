#!/usr/bin/env bash
# One-liner entry point. On a fresh Arch / Arch Linux ARM install, as your
# normal user (not root), with sudo set up:
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/cartermccann/arch-dotfiles/main/bootstrap.sh)
#
# Clones the repo to ~/.local/share/arch-dotfiles (or updates it) and runs
# install.sh with any arguments you pass.
set -euo pipefail

REPO=${ARCH_DOTFILES_REPO:-https://github.com/cartermccann/arch-dotfiles.git}
DEST=${ARCH_DOTFILES_DIR:-$HOME/.local/share/arch-dotfiles}

[ "$(id -u)" -ne 0 ] || { echo "run this as your normal user, not root (it uses sudo when it needs to)"; exit 1; }
[ -f /etc/arch-release ] || { echo "this is for Arch Linux / Arch Linux ARM"; exit 1; }

command -v git >/dev/null || sudo pacman -Syu --needed --noconfirm git

if [ -d "$DEST/.git" ]; then
  git -C "$DEST" pull --ff-only
else
  mkdir -p "$(dirname "$DEST")"
  git clone "$REPO" "$DEST"
fi

exec "$DEST/install.sh" "$@"
