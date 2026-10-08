# PHASE: Ly login screen (cobalt colormix theme from Carter's gentoo-dotfiles)
if [ "$CHECK" = 0 ]; then
  sed "s/__HOSTNAME__/$(cat /etc/hostname 2>/dev/null || uname -n)/" "$REPO_DIR/config/ly/config.ini" > "$STATE_DIR/ly.ini"
  install_root "$STATE_DIR/ly.ini" /etc/ly/config.ini
  # Only one display manager can own the screen.
  other=$(readlink /etc/systemd/system/display-manager.service 2>/dev/null)
  if [ -n "$other" ] && [[ $other != *ly* ]]; then
    warn "another display manager is enabled ($other); disabling it in favour of Ly"
    sudo_run systemctl disable "$(basename "$other")"
  fi
fi
# Newer ly ships a templated unit (ly@tty2); older ones a plain ly.service.
if systemctl cat ly@.service >/dev/null 2>&1; then
  [ "$CHECK" = 0 ] && sudo_run systemctl disable getty@tty2.service 2>/dev/null
  enable_unit ly@tty2.service
else
  enable_unit ly.service
fi
[ "$CHECK" = 0 ] && note "Ly takes effect on the next boot (it runs on tty2; Ctrl+Alt+F1 is still a plain console)"
true
