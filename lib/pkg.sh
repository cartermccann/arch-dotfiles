# shellcheck shell=bash
# Package resolution for packages/*.list (format: packages/README.md).
# Sourced after lib/common.sh.

declare -A _AUR_ARCH_CACHE=()

# Does the AUR have NAME, built for this architecture? Existence comes from
# the RPC: the cgit .SRCINFO pages outlive packages deleted from the AUR, so
# they alone would "resolve" names that paru can no longer install. The
# architectures come from .SRCINFO (the RPC doesn't report them).
aur_ok() {
  local name=$1 archs
  if [ -z "${_AUR_ARCH_CACHE[$name]+x}" ]; then
    if [ "$(curl -fsSL --max-time 20 "https://aur.archlinux.org/rpc/v5/info?arg%5B%5D=$name" 2>/dev/null | jq -r .resultcount 2>/dev/null)" = 1 ]; then
      archs=$(curl -fsSL --max-time 20 "https://aur.archlinux.org/cgit/aur.git/plain/.SRCINFO?h=$name" 2>/dev/null \
        | awk '/^\s*arch = /{print $3}' | tr '\n' ' ')
    else
      archs=MISSING
    fi
    _AUR_ARCH_CACHE[$name]=$archs
  fi
  archs=${_AUR_ARCH_CACHE[$name]}
  [[ " $archs " != *" MISSING "* ]] && [[ " $archs " == *" $ARCH "* || " $archs " == *" any "* ]]
}

repo_ok() { pacman -Si "$1" >/dev/null 2>&1; }

# install_list FILE: resolve every line, then install repo packages in one
# pacman transaction, AUR packages in one paru run, and run fallbacks.
install_list() {
  local file=$1 raw line only words cands fallback w i resolved p
  local -a repo=() aur=() fallbacks=()
  step "packages/$(basename "$file")"
  while IFS= read -r raw || [ -n "$raw" ]; do
    line=${raw%%#*}
    line="${line#"${line%%[![:space:]]*}"}"   # trim leading
    line="${line%"${line##*[![:space:]]}"}"   # trim trailing
    [ -n "$line" ] || continue
    only=
    if [[ $line =~ ^(x86_64|aarch64):[[:space:]]*(.*)$ ]]; then
      only=${BASH_REMATCH[1]}; line=${BASH_REMATCH[2]}
    fi
    if [ -n "$only" ] && [ "$only" != "$ARCH" ]; then continue; fi
    read -ra words <<<"$line"
    cands=(); fallback=()
    for ((i = 0; i < ${#words[@]}; i++)); do
      w=${words[$i]}
      if [[ $w == @* ]]; then fallback=("${words[@]:$i}"); break; fi
      cands+=("$w")
    done
    resolved=
    for w in "${cands[@]}"; do
      if repo_ok "$w"; then repo+=("$w"); resolved=$w; break; fi
      if aur_ok "$w"; then aur+=("$w"); resolved=$w; break; fi
    done
    if [ -z "$resolved" ]; then
      if [ ${#fallback[@]} -gt 0 ]; then
        fallbacks+=("${fallback[*]}")
      else
        warn "no package for: ${cands[*]} ($ARCH)"
        remember "missing package: ${cands[*]} (nothing resolved on $ARCH)"
      fi
    elif [ "$resolved" != "${cands[0]}" ]; then
      note "${cands[0]} → $resolved"
    fi
  done <"$file"

  if [ "$CHECK" = 1 ]; then
    local missing=()
    for p in "${repo[@]}" "${aur[@]}"; do pacman -Q "$p" >/dev/null 2>&1 || missing+=("$p"); done
    if [ ${#missing[@]} -eq 0 ]; then ok "packages installed"; else warn "not installed: ${missing[*]}"; fi
    repo=(); aur=()   # fall through: the fallbacks below report on themselves
  fi

  if [ ${#repo[@]} -gt 0 ]; then
    if ! sudo_run pacman -S --needed --noconfirm "${repo[@]}"; then
      warn "batch install failed; retrying one by one to find the culprit"
      for p in "${repo[@]}"; do
        sudo_run pacman -S --needed --noconfirm "$p" || remember "pacman failed: $p"
      done
    fi
  fi
  if [ ${#aur[@]} -gt 0 ] && ! have paru && [ "$DRY_RUN" = 1 ]; then
    note "AUR (paru not installed yet in this dry run): ${aur[*]}"; aur=()
  fi
  if [ ${#aur[@]} -gt 0 ]; then
    have paru || die "paru is missing (phase 10-base installs it)"
    note "AUR: ${aur[*]}"
    if ! run paru -S --needed --noconfirm --skipreview "${aur[@]}"; then
      for p in "${aur[@]}"; do
        run paru -S --needed --noconfirm --skipreview "$p" || remember "AUR build failed: $p"
      done
    fi
  fi
  local fb
  for fb in "${fallbacks[@]}"; do
    read -ra words <<<"$fb"
    local handler=fallback_${words[0]#@}
    if declare -F "$handler" >/dev/null; then
      "$handler" "${words[@]:1}"
    else
      warn "unknown fallback ${words[0]}"
    fi
  done
}

# ── fallbacks ───────────────────────────────────────────────────────

# @skip REASON...: nothing to install on this architecture; say so.
fallback_skip() {
  note "skipped: $*"
  remember "skipped on $ARCH: $*"
}

# @webapp NAME URL: a launcher that opens URL as a standalone Chrome window.
fallback_webapp() {
  local name=$1 url=$2 id
  id=webapp-$(echo "$name" | tr '[:upper:]' '[:lower:]')
  local f=$HOME/.local/share/applications/$id.desktop
  if [ "$CHECK" = 1 ]; then [ -f "$f" ] && ok "$name web app" || warn "$name web app missing"; return; fi
  run mkdir -p "$(dirname "$f")"
  if [ "$DRY_RUN" = 0 ]; then
    cat >"$f" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Comment=$name (web app; no native $ARCH build)
Exec=ouranos-browser --app=$url
Icon=$(echo "$name" | tr '[:upper:]' '[:lower:]')
Categories=Network;
EOF
  fi
  note "$name → web app ($url)"
  remember "$name: installed as a Chrome web app (no native package for $ARCH)"
}

# @appimage NAME: download the vendor's AppImage for this architecture.
appimage_url() {
  local a
  case "$1" in
    cursor)
      [ "$ARCH" = aarch64 ] && a=linux-arm64 || a=linux-x64
      curl -fsSL "https://www.cursor.com/api/download?platform=$a&releaseTrack=stable" | jq -r .downloadUrl ;;
    ghostty)
      # community AppImage build (pkgforge-dev/ghostty-appimage, MIT); upstream ships no Linux binaries
      curl -fsSL https://api.github.com/repos/pkgforge-dev/ghostty-appimage/releases/latest \
        | jq -r --arg a "$ARCH" '.assets[] | select(.name | endswith("-" + $a + ".AppImage")) | .browser_download_url' | head -1 ;;
    obsidian)
      curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest \
        | jq -r --arg arm "$([ "$ARCH" = aarch64 ] && echo 1)" \
          '.assets[] | select(.name | endswith(".AppImage")) | select((.name | test("arm64")) == ($arm == "1")) | .browser_download_url' \
        | head -1 ;;
  esac
}
fallback_appimage() {
  local name=$1 dir=$HOME/.local/opt/$1 url
  local bin=$HOME/.local/bin/$name desk=$HOME/.local/share/applications/$name.desktop
  if [ "$CHECK" = 1 ]; then [ -x "$dir/$name.AppImage" ] && ok "$name AppImage" || warn "$name AppImage missing"; return; fi
  url=$(appimage_url "$name")
  [ -n "$url" ] && [ "$url" != null ] || { warn "no AppImage URL for $name"; remember "could not find a $name AppImage for $ARCH"; return; }
  pacman -Q fuse2 >/dev/null 2>&1 || sudo_run pacman -S --needed --noconfirm fuse2
  run mkdir -p "$dir" "$(dirname "$bin")" "$(dirname "$desk")"
  # download beside it, then move: an interrupted download never looks installed
  run curl -fL --progress-bar -o "$dir/.$name.part" "$url" || { rm -f "$dir/.$name.part"; remember "download failed: $name AppImage"; return; }
  run chmod +x "$dir/.$name.part"
  run mv "$dir/.$name.part" "$dir/$name.AppImage"
  run ln -sf "$dir/$name.AppImage" "$bin"
  if [ "$DRY_RUN" = 0 ]; then
    cat >"$desk" <<EOF
[Desktop Entry]
Type=Application
Name=${name^}
Exec=$bin %U
Icon=$name
Categories=Development;
EOF
  fi
  note "$name → AppImage in ~/.local/opt/$name (update: re-run ./install.sh --only 40-apps)"
  remember "$name installed as an AppImage (no $ARCH package): ~/.local/opt/$name"
}

# @claude-installer: Anthropic's native installer, if the AUR package is unusable.
fallback_claude-installer() {
  have claude && return
  [ "$CHECK" = 1 ] && { warn "claude missing"; return; }
  if [ "$DRY_RUN" = 1 ]; then note "would run the claude.ai/install.sh installer"; return; fi
  curl -fsSL https://claude.ai/install.sh | bash
}

# @mise TOOL: install a CLI through mise when no package exists for this
# architecture (mise pulls the upstream release binary).
fallback_mise() {
  local tool=$1
  if [ "$CHECK" = 1 ]; then mise ls --global 2>/dev/null | grep -q "${tool#*:}" && ok "$tool (mise)" || warn "$tool (mise) missing"; return; fi
  have mise || { remember "could not install $tool: mise is missing"; return; }
  run mise use -g --yes "$tool" && note "$tool → mise (no $ARCH package)" || remember "mise could not install $tool"
}
