# PHASE: system update, pacman tuning, base tools, the paru AUR helper
if [ "$CHECK" = 0 ]; then
  # Colour and parallel downloads: harmless quality-of-life in pacman.conf
  sudo_run sed -i 's/^#Color$/Color/; s/^#\?ParallelDownloads.*/ParallelDownloads = 8/' /etc/pacman.conf
  if [ "$ARCH" = x86_64 ] && grep -q '^#\[multilib\]' /etc/pacman.conf; then
    # 32-bit libraries (Steam, Wine, some drivers' lib32 halves)
    sudo_run sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
    ok "enabled the multilib repo"
  fi
  step "full system upgrade"
  sudo_run pacman -Syu --noconfirm || die "system upgrade failed: fix it (keyring? mirror?) before installing anything else"
fi
# An earlier run (or a manual install) may have pulled in jack2 as the JACK
# provider; it conflicts with pipewire-jack, so swap it out.
if [ "$CHECK" = 0 ] && pacman -Q jack2 >/dev/null 2>&1 && ! pacman -Q pipewire-jack >/dev/null 2>&1; then
  sudo_run pacman -Rdd --noconfirm jack2
fi
install_list "$REPO_DIR/packages/base.list"

# paru: installs AUR packages the same way pacman installs repo ones.
# paru-bin is quick but is linked against one libalpm version, and it breaks
# whenever pacman moves ahead of it ("libalpm.so.N: cannot open shared
# object file"). So: try it, prove it runs, and build from source if not.
paru_works() { paru --version >/dev/null 2>&1; }
aur_build() {
  local tmp; tmp=$(mktemp -d)
  run git clone --depth 1 "https://aur.archlinux.org/$1.git" "$tmp/$1" \
    && ( cd "$tmp/$1" && run makepkg -si --noconfirm )
  local rc=$?; rm -rf "$tmp"; return $rc
}
if paru_works; then
  ok "paru $(paru --version | head -1 | awk '{print $2}')"
elif [ "$CHECK" = 1 ]; then
  warn "paru missing or broken"
else
  step "installing paru (AUR helper)"
  aur_build paru-bin
  if [ "$DRY_RUN" = 0 ] && ! paru_works; then
    warn "paru-bin doesn't run against this pacman; building paru from source (a few minutes)"
    # (makepkg builds a -debug split package by default; it goes too, or
    # its paru.debug file conflicts with the source build's)
    stale=(); for p in paru-bin paru-bin-debug; do pacman -Q "$p" >/dev/null 2>&1 && stale+=("$p"); done
    [ ${#stale[@]} -gt 0 ] && sudo_run pacman -Rns --noconfirm "${stale[@]}"
    # rustup provides cargo, which paru's build needs; phase 25 reuses it
    sudo_run pacman -S --needed --noconfirm rustup
    rustup toolchain list 2>/dev/null | grep -q stable || run rustup default stable
    aur_build paru || die "paru build failed"
  fi
  [ "$DRY_RUN" = 1 ] || paru_works || die "paru still doesn't run"
  ok "paru installed"
fi
