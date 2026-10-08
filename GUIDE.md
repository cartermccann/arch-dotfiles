# How this system works

This guide is for after the install, when you want to understand and change
things. The setup is Carter's (he runs it on NixOS), ported to plain Arch.
Everything here is ordinary Arch: no magic layer, every file is yours to
edit.

## The mental model

```
pacman ── official Arch packages: the system, the desktop, most tools
paru ──── the AUR: community build scripts (Chrome, Claude Code, ...)
mise ──── language runtimes: Node, pnpm, bun, deno, npm-based CLIs
uv ────── Python projects and Python CLIs
rustup ── the Rust toolchain
~/.config ── every app's config (seeded from this repo, then yours)
~/.local/bin ── small helper scripts (menus, bar modules, toggles)
```

**Rule of thumb:** install with `pacman -S` (or `paru -S` for the AUR). Use
`mise` for language versions. Never `sudo npm -g` or `sudo pip`: they fight
pacman over the same files.

## Updating

```fish
up          # paru -Syu (repos + AUR) then mise upgrade; refreshes the bar
```

The bar shows **UPD n** when updates are pending. Click it for the list.
Arch is rolling: update every week or two, not every six months. If an
update ever breaks the desktop, log in on a text console (Ctrl+Alt+F1),
check <https://archlinux.org/news/>, and roll back one package with
`sudo pacman -U /var/cache/pacman/pkg/<package>-<old-version>.pkg.tar.zst`.

## Node and other languages

mise puts the right versions on PATH for whatever directory you're in.

```fish
node -v                       # global default: latest LTS
mise use node@20              # pin Node 20 for THIS project (writes mise.toml)
mise use -g pnpm@latest       # change a global default
mise ls                       # what's installed and active here
mise use -g npm:some-cli      # install an npm CLI globally, the clean way
```

mise also reads `.nvmrc` and `.node-version`, so existing projects just work.
Global choices live in `~/.config/mise/config.toml`.

Python: `uv init`, `uv add requests`, `uv run main.py`. For a CLI, use
`uv tool install ruff`.

Go comes from pacman (`go`) and installs binaries to `~/.local/bin`. Rust
comes from `rustup` (`rustup update`). Docker works without sudo after one
logout/login.

## Where things live

| What | File |
|---|---|
| Hyprland (keys, look, autostart) | `~/.config/hypr/hyprland.lua` |
| This machine's overrides (monitors, GPU, keyboard) | `~/.config/hypr/local.lua` |
| Lock screen / idle timers / night light | `~/.config/hypr/hyprlock.conf`, `hypridle.conf`, `hyprsunset.conf` |
| Bar | `~/.config/waybar/config.jsonc`, `style.css` |
| Colours (bar, notifications, OSD, calendar) | `~/.config/*/_ouranos.css` |
| Launcher | `~/.config/fuzzel/hypr.ini` |
| Ouranos menu (Super+Alt+Space) | `~/.config/ouranos/menu.json` |
| Notifications | `~/.config/swaync/` |
| Terminal | `~/.config/ghostty/config` |
| Shell | `~/.config/fish/config.fish` (machine-only bits: `conf.d/local.fish`) |
| Prompt | `~/.config/starship.toml` |
| tmux (prefix Ctrl+A) | `~/.config/tmux/tmux.conf` |
| Neovim | `~/.config/nvim/` |
| Git | `~/.config/git/config` (shared), `~/.gitconfig` (your name/email) |
| Login screen | `/etc/ly/config.ini` |
| Claude Code's notes about this machine | `~/.claude/CLAUDE.md` |

After editing: Hyprland reloads itself when `hyprland.lua` is saved (Super+Shift+R forces it, e.g. after editing `local.lua`). Reload the bar with
Super+Shift+Space, fish with `exec fish`, and tmux with prefix then `R`.
Check Hyprland edits with `Hyprland --verify-config`.

## Keys

`Super` is the Windows/Command key on a PC. **In the Mac VM it's Option**,
and Alt is Cmd (macOS reserves Cmd). Super+/ searches every binding live,
including Neovim's and tmux's.

| Keys | Does |
|---|---|
| Super+Return | terminal |
| Super+Alt+Return | terminal attached to the tmux session `work` |
| Super+Space | app launcher |
| Super+Alt+Space | Ouranos menu (apps, capture, toggles, share, system) |
| Super+/ | keybinding cheatsheet |
| Super+O | open a project from `~/projects` (tmux + nvim) |
| Super+Shift+B | browser |
| Super+V | clipboard history |
| Super+Q / Super+W | close window |
| Super+H J K L (or arrows) | focus left/down/up/right |
| Super+Shift+H J K L | move window |
| Super+1…0, Super+Shift+1…0 | go to / send to workspace |
| Super+Tab | next workspace |
| Super+F / Super+Shift+F | maximize / fullscreen |
| Super+T | float / tile |
| Super+\` | scratchpad (a drop-down workspace) |
| Super+A | "tmux mode" for windows: then \| or - splits, hjkl moves, z zooms, Esc leaves |
| Super+Shift+S | screenshot an area and annotate it |
| Super+Shift+C | colour picker |
| Super+N | notification centre |
| Super+Ctrl+L | lock |
| Super+Shift+X | power menu |
| Super+Shift+W | wallpaper picker (drop images into `~/wallpapers`) |
| Super+Ctrl+N | night light |
| Super+Alt+R | record the screen (press again to stop) |
| Super+B | hide/show the bar |
| Super+Shift+E | log out |

**Terminal:** in fish, `dev` opens nvim plus two shells in tmux, `t`
attaches the `work` session, `y` is the yazi file manager, `lazygit` is git,
and `gwa <branch>` / `gwr` add and remove git worktrees. Ctrl+R searches
history (atuin), and `z <dir>` jumps to a directory you've visited.

## The bar, left to right

Workspaces, then the modes drawer (hover the `⋯`): night light, caffeine
(screen stays on), do not disturb, recording. Active modes light up. Then
the clock (click it for a calendar, right-click for ISO date/week), updates
(only when pending), media, CPU/MEM, network, bluetooth, mic, volume,
notifications, tray and power.

Some modules hide themselves unless their tool exists:
- **GPU temperature** needs an NVIDIA card.
- **Tailscale** is installed but off. It appears after
  `sudo systemctl enable --now tailscaled && sudo tailscale up`.
- **Agents** needs herdr, Carter's agent workspace tool.
- **Calendar events:** create `~/.config/credentials/calendars.toml`:
  ```toml
  [[account]]
  name  = "Personal"
  email = "you@gmail.com"
  urls  = ["https://calendar.google.com/calendar/ical/.../basic.ics"]
  ```
  Use Google Calendar → Settings → your calendar → "Secret address in iCal
  format". Treat it like a password.

## Neovim

The config is plain lazy.nvim with no distro and no Mason. Language servers
are normal binaries installed by the installer, so `:checkhealth` and
`:LspInfo` tell the truth. To add a language, install its server with pacman
or `mise use -g npm:...`, then add it to `~/.config/nvim/lua/lsp.lua`.
Space is the leader key, and Space then waiting shows a menu (which-key).
Inline AI completion (minuet) only turns on if you install ollama; Claude
Code integrates through `:ClaudeCode`.

## Changing things safely

- Configs in this repo are **seeded**. A file you haven't touched follows
  the repo: `git -C ~/.local/share/arch-dotfiles pull && ~/.local/share/arch-dotfiles/install.sh`
  picks up Carter's changes. A file you've edited is never overwritten.
- To see how yours differ from the repo: `~/.local/share/arch-dotfiles/install.sh --check`.
- To take the repo's version of everything anyway: `install.sh --force`.
  Your versions are kept as `*.bak-<date>`.
- `~/.local/bin` helper scripts **are** overwritten on each run, so put your
  own scripts somewhere else (e.g. `~/bin`, and add it in `conf.d/local.fish`).
- Keep `~/.config` in your own git repo once it feels like yours.

## When something breaks

| Symptom | Try |
|---|---|
| Black windows in the VM | `ouranos-gpu --off`, then log out and in |
| Desktop won't start | Ctrl+Alt+F1 → log in → `Hyprland --verify-config`, or `journalctl --user -b` |
| Bar missing | Super+Shift+Space, or run `waybar` in a terminal to see the error |
| No sound | `pavucontrol` (Super+Ctrl+A); pick the output with Super+Ctrl+S |
| Clipboard not shared (VM) | `systemctl --user status ouranos-vdagent`; UTM clipboard sharing must be on |
| A command is missing | `install.sh --check` lists what's not installed |
| Package conflict on update | read the message, check archlinux.org/news, don't force it |
| Anything else | ask Claude Code (`claude`): `~/.claude/CLAUDE.md` tells it how this machine is set up |

The Arch Wiki (<https://wiki.archlinux.org>) is the best Linux documentation
there is. Search it first.
