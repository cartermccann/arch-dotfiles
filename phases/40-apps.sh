# PHASE: desktop apps: Chrome, Ghostty, Obsidian, Cursor, LocalSend, media, office (web apps where there's no ARM build)
install_list "$REPO_DIR/packages/apps.list"
[ "$CHECK" = 1 ] && return 0
for d in google-chrome chromium; do
  if [ -f "/usr/share/applications/$d.desktop" ]; then
    run xdg-settings set default-web-browser "$d.desktop" 2>/dev/null || true
    run xdg-mime default "$d.desktop" x-scheme-handler/http x-scheme-handler/https text/html
    ok "default browser: $d"
    break
  fi
done
have update-desktop-database && run update-desktop-database "$HOME/.local/share/applications" 2>/dev/null
true
