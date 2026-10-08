# PHASE: doctor: everything on PATH, Hyprland config valid, Neovim loads, Ly enabled
missing=()
for c in hyprland hyprlock hypridle waybar fuzzel swaync swayosd-server ghostty nvim fish starship tmux \
         git gh lazygit rg fd eza bat yazi zoxide atuin fzf btop jq mise docker claude; do
  have "$c" || missing+=("$c")
done
for c in node pnpm codex; do
  have "$c" || [ -x "$HOME/.local/share/mise/shims/$c" ] || missing+=("$c")
done
if [ ${#missing[@]} -eq 0 ]; then ok "every core command is installed"
else fail "missing: ${missing[*]}"; remember "missing commands: ${missing[*]}"; fi

if have Hyprland && [ -f "$HOME/.config/hypr/hyprland.lua" ]; then
  # Hyprland refuses to start (even just to verify) without a runtime dir,
  # which a bare TTY/ssh/container shell may not have.
  rt=${XDG_RUNTIME_DIR:-$(mktemp -d)}
  if out=$(XDG_RUNTIME_DIR=$rt Hyprland --verify-config -c "$HOME/.config/hypr/hyprland.lua" 2>&1) && grep -q "config ok" <<<"$out"; then
    ok "Hyprland config: ok"
  else
    fail "Hyprland config has errors:"; tail -15 <<<"$out" | sed 's/^/      /'
    remember "Hyprland config errors: run Hyprland --verify-config -c ~/.config/hypr/hyprland.lua"
  fi
fi

if have nvim && [ "$DRY_RUN" = 0 ]; then
  # First run installs the plugins pinned in lazy-lock.json (needs network);
  # --check only looks.
  if [ "$CHECK" = 0 ]; then
    timeout 300 nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 || warn "neovim plugin restore timed out or failed"
  fi
  # (treesitter parser installs can print alongside, hence the marker)
  scheme=$(nvim --headless "+lua io.write('COLORS=' .. (vim.g.colors_name or 'none') .. '\\n')" +qa 2>&1 | sed -n 's/.*COLORS=//p' | head -1)
  if [ "$scheme" = palette ]; then ok "neovim: plugins restored, palette colorscheme loads"
  else fail "neovim colorscheme is '$scheme', expected 'palette'"; remember "neovim: run nvim and check :messages / :checkhealth"; fi
fi

if systemctl is-enabled --quiet ly@tty2.service 2>/dev/null || systemctl is-enabled --quiet ly.service 2>/dev/null; then
  ok "Ly login screen enabled"
else
  warn "Ly is not enabled"
fi
