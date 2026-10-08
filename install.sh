#!/usr/bin/env bash
# arch-dotfiles installer: Carter's Hyprland/Neovim/CLI setup on Arch Linux
# (x86_64) or Arch Linux ARM (aarch64, e.g. a UTM VM on an Apple Silicon Mac).
#
#   ./install.sh                 run every phase (safe to re-run any time)
#   ./install.sh --list          list the phases
#   ./install.sh --only 40-apps  run one phase (repeatable)
#   ./install.sh --from 30       start at a phase
#   ./install.sh --check         doctor: report what's missing or differs, change nothing
#   ./install.sh --dry-run       print what would run
#   ./install.sh --force         replace configs you've edited (backups are kept)
#
# Every config under config/ is "seeded": copied only if you don't already
# have one, so re-running never clobbers your edits. See GUIDE.md.
set -uo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export REPO_DIR

ONLY=() FROM=""
while [ $# -gt 0 ]; do
  case "$1" in
    --list) for f in "$REPO_DIR"/phases/*.sh; do
              printf '%-14s %s\n' "$(basename "$f" .sh)" "$(sed -n 's/^# PHASE: //p' "$f")"
            done; exit 0 ;;
    --only) [ $# -ge 2 ] || { echo "--only needs a phase (see --list)" >&2; exit 1; }; ONLY+=("$2"); shift ;;
    --from) [ $# -ge 2 ] || { echo "--from needs a phase (see --list)" >&2; exit 1; }; FROM=$2; shift ;;
    --check) export CHECK=1 ;;
    --dry-run) export DRY_RUN=1 ;;
    --force) export FORCE=1 ;;
    -h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$0"; exit 0 ;;
    *) echo "unknown option: $1 (try --help)" >&2; exit 1 ;;
  esac
  shift
done

# shellcheck source=lib/common.sh
. "$REPO_DIR/lib/common.sh"
# shellcheck source=lib/pkg.sh
. "$REPO_DIR/lib/pkg.sh"

: >"$SUMMARY"

# Keep sudo alive for the whole run (AUR builds can take a while).
if [ "$CHECK" = 0 ] && [ "$DRY_RUN" = 0 ] && [ "$(id -u)" -ne 0 ]; then
  sudo -v || die "sudo is required"
  while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
  SUDO_KEEPALIVE=$!
  trap 'kill $SUDO_KEEPALIVE 2>/dev/null' EXIT
fi

start=$(date +%s)
for f in "$REPO_DIR"/phases/*.sh; do
  name=$(basename "$f" .sh)
  if [ ${#ONLY[@]} -gt 0 ]; then
    match=0
    for o in "${ONLY[@]}"; do [[ $name == "$o"* ]] && match=1; done
    [ $match = 1 ] || continue
  elif [ -n "$FROM" ] && [[ $name < $FROM ]]; then
    continue
  fi
  phase "$name · $(sed -n 's/^# PHASE: //p' "$f")"
  # shellcheck source=/dev/null
  if ! ( . "$f" ); then
    fail "phase $name failed"
    # Nothing after these can work without them.
    case $name in 00-*|10-*) die "stopping: fix the error above, then re-run ./install.sh" ;; esac
    remember "phase $name failed: re-run ./install.sh --only $name"
  fi
done

echo
if [ -s "$SUMMARY" ]; then
  phase "things to know"
  sed 's/^/  • /' "$SUMMARY"
fi
if [ "$CHECK" = 1 ] && [ -s "$STATE_DIR/summary.txt" ]; then
  phase "notes from the last install"
  sed 's/^/  • /' "$STATE_DIR/summary.txt"
fi
[ "$CHECK" = 1 ] || printf '\n%sdone in %ss.%s Reboot, log in through Ly, pick Hyprland. Super+/ lists every key.\n' \
  "$C_GREEN" "$(( $(date +%s) - start ))" "$C_RESET"
