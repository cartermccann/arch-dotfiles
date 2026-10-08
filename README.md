# arch-dotfiles

Carter's desktop and dev setup, ported from his NixOS flake to plain Arch
Linux. You get Hyprland with his Lua config, the Waybar ("Ouranos" glass
theme), fuzzel menus, his Neovim config, Ghostty, fish + starship + tmux, the
whole CLI toolbelt, the same apps (Chrome instead of Zen), Claude Code and
Codex, and Node managed by mise.

It runs on **x86_64 Arch** and **aarch64 Arch Linux ARM**. The aarch64 path
targets a UTM virtual machine on an Apple Silicon Mac. M4 and M5 Macs can't
boot Linux natively yet (Asahi stops at M3), so a VM is the way in.

## Install

**On an Apple Silicon Mac:** follow [docs/UTM-SETUP.md](docs/UTM-SETUP.md).
It covers creating the VM and the base Arch install (about 20 minutes), and
ends at the step below.

**On any Arch install** (as your normal user, with sudo working):

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/cartermccann/arch-dotfiles/main/bootstrap.sh)
```

That clones this repo to `~/.local/share/arch-dotfiles` and runs
`install.sh`. Expect 20 to 60 minutes; some AUR packages compile on ARM.
Then reboot, log in through Ly, and pick Hyprland. Press **Super+/** for
every keybinding.

## Then read

[GUIDE.md](GUIDE.md) explains how the system fits together: where configs
live, how packages and Node work, how to update, the keys, and what to do
when something breaks.

## Installer flags

```
./install.sh --list           phases
./install.sh --only 40-apps   one phase (repeatable)
./install.sh --from 30        start at a phase
./install.sh --check          doctor: what's missing or differs; changes nothing
./install.sh --dry-run        print what would run
./install.sh --force          replace configs you've edited (backups kept)
```

Re-running is always safe. A config you haven't touched is updated to the
repo's version; one you've edited is left alone (`--check` shows the diff).

## Layout

| Path | What |
|---|---|
| `install.sh`, `bootstrap.sh` | entry points |
| `phases/` | install steps, in order |
| `packages/*.list` | what gets installed, with ARM fallbacks ([format](packages/README.md)) |
| `config/` | everything that lands in `~/.config` |
| `bin/` | helper scripts → `~/.local/bin` (menus, bar modules, toggles) |
| `vm/install-arch-arm.sh` | base install inside a fresh UTM VM |
| `scripts/check-packages.py` | resolves every package list against the real x86_64/aarch64 repos + AUR |
| `claude/CLAUDE.md` | starter context for Claude Code about this machine |

## License and credits

MIT ([LICENSE](LICENSE)). The UTM clipboard bridge (`bin/ouranos-vdagent`)
is vendored from [ggalancs/omarchy-arm-utm](https://github.com/ggalancs/omarchy-arm-utm),
whose software-rendering toggle also inspired `ouranos-gpu`. The VM base
installer is adapted from [Cua's](https://github.com/trycua/cua) Archboot
script. The Ghostty cursor shaders come from
[sahaj-b/ghostty-cursor-shaders](https://github.com/sahaj-b/ghostty-cursor-shaders).
Their licenses are in [THIRD_PARTY.md](THIRD_PARTY.md).
