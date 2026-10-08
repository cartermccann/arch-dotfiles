# PHASE: services: NetworkManager, bluetooth, docker, printing, time sync, clipboard agent (VM)
enable_unit bluetooth.service docker.socket cups.socket systemd-timesyncd.service
# NetworkManager (what the bar and nmtui talk to), unless the network is
# already run by something else: two managers on one interface fight, and
# starting NM mid-install could drop the connection.
others=()
for u in systemd-networkd.service iwd.service dhcpcd.service; do
  systemctl is-enabled --quiet "$u" 2>/dev/null && others+=("${u%.service}")
done
if [ ${#others[@]} -eq 0 ] || systemctl is-enabled --quiet NetworkManager.service 2>/dev/null; then
  enable_unit NetworkManager.service
else
  warn "network is managed by ${others[*]}; leaving it alone"
  remember "network: ${others[*]} manages your connection, so NetworkManager was not enabled. To switch (the bar's network menu uses it): sudo systemctl disable --now ${others[*]/%/.service} && sudo systemctl enable --now NetworkManager"
fi
if [ "$IS_VM" = 1 ]; then
  if [ "$CHECK" = 0 ]; then
    run install -Dm644 "$REPO_DIR/config/systemd/ouranos-vdagent.service" "$HOME/.config/systemd/user/ouranos-vdagent.service"
    run systemctl --user daemon-reload
    # The stock session agent is X11-only; only one agent may talk to vdagentd.
    run systemctl --user mask spice-vdagent.service 2>/dev/null || true
  fi
  # Started by Hyprland itself (local.lua), so nothing to enable here.
  [ -f "$HOME/.config/systemd/user/ouranos-vdagent.service" ] && ok "clipboard agent unit installed" || warn "clipboard agent unit missing"
fi
true
