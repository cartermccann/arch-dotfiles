# PHASE: configs into ~/.config (never overwriting your edits), scripts into ~/.local/bin, fish as your shell
C=$REPO_DIR/config
for d in hypr waybar swaync swayosd fuzzel ghostty fish tmux git nvim ouranos ouranos-calendar lazygit btop bat yazi; do
  seed_copy "$C/$d" "$HOME/.config/$d"
done
seed_copy "$C/starship.toml" "$HOME/.config/starship.toml"
seed_copy "$REPO_DIR/config/profile" "$HOME/.profile"

# Helper scripts and their data are tooling, not config: always refreshed.
if [ "$CHECK" = 1 ]; then
  for f in "$REPO_DIR"/bin/*; do [ -x "$HOME/.local/bin/$(basename "$f")" ] || warn "missing: ~/.local/bin/$(basename "$f")"; done
else
  run install -Dm755 -t "$HOME/.local/bin" "$REPO_DIR"/bin/*
  run install -Dm644 -t "$HOME/.local/share/ouranos" "$REPO_DIR"/share/ouranos/*
  # A quiet Ouranos backdrop (near-black, faint cobalt glow from the top),
  # drawn here so no image with someone else's copyright ships in the repo.
  # Drop your own into ~/wallpapers and pick with Super+Shift+W.
  if [ "$DRY_RUN" = 0 ] && ! compgen -G "$HOME/wallpapers/*" >/dev/null && have magick; then
    mkdir -p "$HOME/wallpapers"
    magick -size 2560x1440 xc:'#0a0c11' \( -size 4400x4400 radial-gradient:'#172453'-'#0a0c11' \) \
      -gravity north -geometry +0-2200 -compose lighten -composite "$HOME/wallpapers/ouranos.png"
  fi
  [ -e "$HOME/wallpaper.png" ] || { [ -f "$HOME/wallpapers/ouranos.png" ] && run cp "$HOME/wallpapers/ouranos.png" "$HOME/wallpaper.png"; }
  have bat && run bat cache --build >/dev/null
fi

# Git identity lives in ~/.gitconfig (shared settings are in ~/.config/git/config)
if [ -z "$(git config --global user.name)" ]; then
  if [ "$CHECK" = 1 ]; then warn "git user.name not set"
  elif [ -t 0 ] && [ "$DRY_RUN" = 0 ]; then
    read -rp "  git name (for commits): " gname
    read -rp "  git email: " gemail
    [ -n "$gname" ] && git config --global user.name "$gname"
    [ -n "$gemail" ] && git config --global user.email "$gemail"
  else
    remember "set your git identity: git config --global user.name 'You'; git config --global user.email you@example.com"
  fi
fi
if have gh; then
  if gh auth status >/dev/null 2>&1; then [ "$CHECK" = 0 ] && run gh auth setup-git
  else remember "GitHub: run 'gh auth login', then 'gh auth setup-git'"; fi
fi

# fish as the login shell
if [ "$(getent passwd "$USER" | cut -d: -f7)" != /usr/bin/fish ]; then
  if [ "$CHECK" = 1 ]; then warn "login shell is not fish"
  else sudo_run chsh -s /usr/bin/fish "$USER" && ok "login shell: fish"; fi
fi
true
