# PHASE: sanity checks (Arch, not root, network, architecture)
[ "$(id -u)" -ne 0 ] || die "run as your normal user, not root"
[ -f /etc/arch-release ] || die "this installer is for Arch Linux / Arch Linux ARM"
case "$ARCH" in
  x86_64|aarch64) ok "architecture: $ARCH" ;;
  *) die "unsupported architecture: $ARCH" ;;
esac
if [ "$IS_VM" = 1 ]; then ok "virtual machine: $VIRT"; else ok "bare metal"; fi
curl -fsS --max-time 10 -o /dev/null https://archlinux.org || curl -fsS --max-time 10 -o /dev/null https://archlinuxarm.org \
  || die "no network: connect first (nmtui, or iwctl on a fresh install)"
ok "network"
have sudo || die "sudo is missing: as root, pacman -S sudo, then EDITOR=nano visudo and uncomment the %wheel line"
id -nG | grep -qw wheel || warn "you are not in the wheel group; sudo may refuse"
