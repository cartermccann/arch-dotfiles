# PHASE: the CLI toolbelt (ripgrep, fd, eza, bat, yazi, lazygit, btop, atuin, ...)
install_list "$REPO_DIR/packages/cli.list"
[ "$CHECK" = 0 ] && have tldr && { run tldr --update >/dev/null 2>&1 || true; }
true
