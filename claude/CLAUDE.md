# This machine

Arch Linux, set up from the `arch-dotfiles` repo (a port of Carter McCann's
NixOS setup). The checkout is at `~/.local/share/arch-dotfiles`; its
`GUIDE.md` is the human-facing explanation of everything below.

Before changing anything here, check `uname -m` and `systemd-detect-virt`:
this may be **Arch Linux ARM (aarch64) in a UTM VM on an Apple Silicon Mac**,
or x86_64 Arch on real hardware. On aarch64, many AUR `-bin` packages are
x86-only. Check a package's `arch=` before recommending it, and prefer
official ARM AppImages or web apps when there's no aarch64 build.

## How software gets installed

- System packages: `sudo pacman -S <pkg>`. AUR: `paru -S <pkg>`. Update everything: `up` (fish function).
- Node/pnpm/bun/deno and npm-distributed CLIs: **mise** (`mise use -g node@lts`,
  `mise use -g npm:<pkg>`, per-project `mise use node@20`). Never `sudo npm -g`.
- Python: `uv` (projects: `uv init/add/run`; CLIs: `uv tool install`). Never `sudo pip`.
- Rust: `rustup`. Go: pacman `go`, binaries land in `~/.local/bin`.
- The installer's package lists are in `~/.local/share/arch-dotfiles/packages/*.list`.

## Desktop

- Hyprland 0.56 with a **Lua** config: `~/.config/hypr/hyprland.lua`, not the old
  hyprlang `hyprland.conf`. Most online examples use the old syntax; translate them
  (`hl.bind`, `hl.config`, `hl.window_rule`, `hl.dsp.*`). Validate with
  `Hyprland --verify-config -c ~/.config/hypr/hyprland.lua`.
- Machine-specific overrides (monitors, GPU env, VM tweaks, kb_options) go in
  `~/.config/hypr/local.lua`, which is loaded last.
- In the VM: `ouranos-gpu --on|--off` switches hardware vs software rendering,
  Option acts as Super (altwin swap), and the clipboard is bridged by `ouranos-vdagent`.
- Bar: Waybar (`~/.config/waybar/`), launcher: fuzzel, notifications: swaync,
  OSD: swayosd, lock/idle: hyprlock/hypridle, wallpaper: awww, login: Ly.
- Helper scripts (menus, bar modules) are in `~/.local/bin/ouranos-*` and `hypr-*`,
  and get overwritten when the installer re-runs. Put changes in a new script instead.

## Shell and editor

- fish + starship + tmux (prefix Ctrl+A). Aliases: `ls`=eza, `cat`=bat, `grep`=rg.
- Neovim: plain lazy.nvim, native LSP, **no Mason**. Servers are system binaries;
  the list is in `~/.config/nvim/lua/lsp.lua`.

## Conventions

- Prefer editing config files over running one-off commands that won't survive a reboot.
- Configs under `~/.config` were seeded from the repo and are the user's now;
  `install.sh --check` shows how they differ from upstream.
