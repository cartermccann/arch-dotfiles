# PHASE: languages + toolchains: mise (Node/pnpm/bun/deno), Go, Rust, Python/uv, Docker, Neovim + LSPs
install_list "$REPO_DIR/packages/dev.list"

# Rust: rustup manages the toolchain (rust-analyzer included)
if have rustup; then
  if [ "$CHECK" = 1 ]; then
    rustup toolchain list 2>/dev/null | grep -q stable && ok "rust stable" || warn "no rust toolchain (rustup default stable)"
  else
    rustup toolchain list 2>/dev/null | grep -q stable || run rustup default stable
    # idempotent; the toolchain may already exist from building paru in phase 10
    run rustup component add rust-analyzer rust-src || remember "rustup: could not add rust-analyzer"
  fi
fi

# Docker without sudo
if ! id -nG "$USER" | grep -qw docker; then
  if [ "$CHECK" = 1 ]; then warn "$USER not in the docker group"
  else sudo_run usermod -aG docker "$USER" || remember "could not add $USER to the docker group"; remember "docker: log out and back in once so 'docker' works without sudo"; fi
fi

# mise: global language runtimes + npm-distributed CLIs/LSPs.
# `mise use -g` records them in ~/.config/mise/config.toml, which is the one
# place to see (and change) what's installed this way.
MISE_TOOLS=(
  node@lts pnpm@latest bun@latest deno@latest
  npm:typescript
  npm:@vtsls/language-server
  npm:@tailwindcss/language-server
  npm:vscode-langservers-extracted
  npm:@fsouza/prettierd
)
if have mise; then
  if [ "$CHECK" = 1 ]; then
    mise ls --global --current 2>/dev/null | sed 's/^/    /'
  else
    step "mise: ${MISE_TOOLS[*]}"
    # Honour .nvmrc / .node-version in existing projects (off by default in mise)
    run mise settings set idiomatic_version_file_enable_tools node
    run mise use -g --yes "${MISE_TOOLS[@]}" || remember "mise could not install some tools: run 'mise use -g node@lts' to see why"
  fi
else
  warn "mise missing; Node won't be installed"
fi
