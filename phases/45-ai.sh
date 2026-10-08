# PHASE: AI CLIs: Claude Code, Codex, opencode + a starter ~/.claude/CLAUDE.md about this system
install_list "$REPO_DIR/packages/ai.list"
if have mise; then
  if [ "$CHECK" = 1 ]; then { have codex || [ -x "$HOME/.local/share/mise/shims/codex" ]; } && ok "codex" || warn "codex missing"
  else run mise use -g --yes npm:@openai/codex || remember "codex: 'mise use -g npm:@openai/codex' failed"; fi
fi
# Claude Code reads ~/.claude/CLAUDE.md in every session: a map of this
# machine so it can help without guessing. Seeded once; edit it as you learn.
seed_copy "$REPO_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
[ "$CHECK" = 0 ] && remember "Claude Code: run 'claude' once and sign in with your own account"
true
