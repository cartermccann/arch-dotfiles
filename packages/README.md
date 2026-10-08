# Package lists

One line per thing to install. The installer (`lib/pkg.sh`) resolves each line
to the first candidate that exists **for this CPU architecture**:

```
ripgrep                       # official repos (pacman), else the AUR (paru)
google-chrome chromium        # first candidate that resolves wins
x86_64: gpu-screen-recorder   # only on that architecture (x86_64 | aarch64)
slack-desktop @webapp Slack https://app.slack.com/client
                              # nothing resolved → run a fallback handler
```

Fallback handlers (`@name args...`) live in `lib/pkg.sh` as `fallback_<name>`:

| Handler | Does |
|---|---|
| `@appimage NAME` | downloads the vendor's AppImage for this architecture to `~/.local/opt/NAME` |
| `@webapp NAME URL` | a launcher that opens URL as a Chrome app window |
| `@mise TOOL` | installs the upstream release binary through mise |
| `@skip REASON` | nothing to install here; says so in the summary |

AUR names are checked against the AUR RPC (the cgit pages outlive deleted
packages) and against the PKGBUILD's `arch=` list.
Anything that resolves to nothing is listed in the summary at the end of the
install, never silently dropped.

`scripts/check-packages.py` resolves every list against the real x86_64 and
aarch64 repo databases plus the AUR, so a typo shows up before anyone runs it.
