# shellcheck shell=bash
# Shared helpers for install.sh and phases/*.sh. Sourced, never executed.

REPO_DIR=${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
ARCH=$(uname -m)                                  # x86_64 | aarch64
# VMs only (qemu, kvm, apple, ...), not containers. It prints "none" itself
# when there is no VM, so only fall back when it printed nothing at all.
VIRT=${ARCH_DOTFILES_VIRT:-$(systemd-detect-virt --vm 2>/dev/null)}; VIRT=${VIRT:-none}  # override for testing
IS_VM=0; [ "$VIRT" != none ] && IS_VM=1
USER=${USER:-$(id -un)}
export USER
DRY_RUN=${DRY_RUN:-0}
CHECK=${CHECK:-0}
FORCE=${FORCE:-0}
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/arch-dotfiles
# What the person needs to know at the end. --check keeps its own list, so a
# doctor run never rewrites the last install's notes.
SUMMARY=$STATE_DIR/summary.txt
[ "$CHECK" = 1 ] && SUMMARY=$STATE_DIR/check-summary.txt
mkdir -p "$STATE_DIR"

# ── output ──────────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_BLUE=$'\e[38;2;59;107;255m'; C_DIM=$'\e[38;2;139;147;164m'
  C_GREEN=$'\e[38;2;52;211;153m'; C_YELLOW=$'\e[38;2;251;191;36m'
  C_RED=$'\e[38;2;248;113;113m'; C_BOLD=$'\e[1m'; C_RESET=$'\e[0m'
else
  C_BLUE='' C_DIM='' C_GREEN='' C_YELLOW='' C_RED='' C_BOLD='' C_RESET=''
fi
phase() { printf '\n%s%s━━ %s%s\n' "$C_BOLD" "$C_BLUE" "$*" "$C_RESET"; }
step()  { printf '%s→%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()    { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()  { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
fail()  { printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
note()  { printf '  %s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }
die()   { fail "$*"; exit 1; }

# Things the person needs to know at the end (skipped apps, manual steps).
remember() { printf '%s\n' "$*" >> "$SUMMARY"; }

# Run a command, or just print it under --dry-run.
run() {
  if [ "$DRY_RUN" = 1 ]; then
    printf '  %s$ %s%s\n' "$C_DIM" "$*" "$C_RESET"
  else
    "$@"
  fi
}
sudo_run() { run sudo "$@"; }

have() { command -v "$1" >/dev/null 2>&1; }

# ── files ───────────────────────────────────────────────────────────
# seed_copy SRC DEST: put a config in place without clobbering your edits.
# The hash of what was last seeded is recorded under $STATE_DIR/seeded, so
# it can tell "you edited this" apart from "the repo has a newer version":
#   DEST missing                  → copy
#   DEST untouched since seeding  → updated to the repo's version
#   DEST edited by you            → kept; --check shows the diff, --force
#                                   backs yours up to DEST.bak-<date> and replaces it
seed_copy() {
  local src=$1 dest=$2
  if [ -d "$src" ]; then
    local f rel
    while IFS= read -r -d '' f; do
      rel=${f#"$src"/}
      seed_copy "$f" "$dest/$rel"
    done < <(find "$src" -type f -print0)
    return
  fi
  local rec=$STATE_DIR/seeded/${dest#"$HOME"/}.sha256 want seeded
  want=$(sha256sum "$src" | cut -d' ' -f1)
  record() { [ "$DRY_RUN" = 1 ] || { mkdir -p "$(dirname "$rec")"; echo "$want" > "$rec"; }; }
  if [ ! -e "$dest" ]; then
    [ "$CHECK" = 1 ] && { warn "missing: ${dest/#$HOME/\~}"; return; }
    run mkdir -p "$(dirname "$dest")"
    run cp "$src" "$dest"; record
    return
  fi
  if cmp -s "$src" "$dest"; then [ "$CHECK" = 1 ] || record; return; fi
  seeded=$(cat "$rec" 2>/dev/null)
  if [ -n "$seeded" ] && [ "$(sha256sum "$dest" | cut -d' ' -f1)" = "$seeded" ]; then
    if [ "$CHECK" = 1 ]; then note "newer in the repo (install.sh will update it): ${dest/#$HOME/\~}"
    else run cp "$src" "$dest"; record; note "updated: ${dest/#$HOME/\~}"; fi
    return
  fi
  if [ "$CHECK" = 1 ]; then
    note "you've changed: ${dest/#$HOME/\~} (diff vs the repo)"
    diff -u --color=auto "$dest" "$src" | sed 's/^/      /' | head -40
  elif [ "$FORCE" = 1 ]; then
    run cp "$dest" "$dest.bak-$(date +%Y%m%d-%H%M%S)"
    run cp "$src" "$dest"; record
    note "replaced (backup kept): ${dest/#$HOME/\~}"
  else
    note "kept your edited ${dest/#$HOME/\~} (--force to replace)"
  fi
}

# install_root SRC DEST [MODE]: a system file, installed with sudo.
install_root() {
  local src=$1 dest=$2 mode=${3:-0644}
  if [ -f "$dest" ] && { cmp -s "$src" "$dest" 2>/dev/null || { [ "$CHECK" = 0 ] && sudo cmp -s "$src" "$dest"; }; }; then return; fi
  [ "$CHECK" = 1 ] && { warn "differs or missing: $dest"; return; }
  sudo_run install -D -m "$mode" "$src" "$dest"
}

# enable_unit [--user] UNIT...: enable (and start) systemd units, idempotently.
enable_unit() {
  local scope=()
  [ "$1" = --user ] && { scope=(--user); shift; }
  local u
  for u in "$@"; do
    if [ "$CHECK" = 1 ]; then
      systemctl "${scope[@]}" is-enabled --quiet "$u" 2>/dev/null && ok "$u enabled" || warn "$u not enabled"
      continue
    fi
    if [ ${#scope[@]} -eq 0 ]; then
      sudo_run systemctl enable --now "$u" || warn "could not enable $u"
    else
      run systemctl --user enable --now "$u" 2>/dev/null || run systemctl --user enable "$u" || warn "could not enable $u"
    fi
  done
}
