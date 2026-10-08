# PHASE: Hyprland desktop: compositor, Waybar, fuzzel, swaync, lock/idle, audio, bluetooth, fonts, theme
install_list "$REPO_DIR/packages/desktop.list"
[ "$CHECK" = 1 ] && return 0

run xdg-user-dirs-update
run mkdir -p "$HOME/Pictures/Screenshots" "$HOME/Videos/Recordings" "$HOME/projects"

# GTK/icon/cursor/font theme. gsettings needs a session bus; outside a
# desktop session dbus-run-session provides one.
gs() { dbus-run-session gsettings set org.gnome.desktop.interface "$@" 2>/dev/null || true; }
if have gsettings && [ "$DRY_RUN" = 0 ]; then
  gs color-scheme prefer-dark
  gs gtk-theme adw-gtk3-dark
  gs icon-theme Papirus-Dark
  gs cursor-theme Bibata-Modern-Ice
  gs cursor-size 24
  gs font-name 'Noto Sans 11'
  gs monospace-font-name 'JetBrainsMono Nerd Font 11'
  ok "GTK theme: adw-gtk3-dark, Papirus-Dark icons, Bibata cursor"
fi
# Cursor for apps that ignore gsettings
if [ "$DRY_RUN" = 0 ]; then
  mkdir -p "$HOME/.icons/default"
  printf '[Icon Theme]\nInherits=Bibata-Modern-Ice\n' > "$HOME/.icons/default/index.theme"
fi
