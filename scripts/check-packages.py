#!/usr/bin/env python3
"""Resolve every packages/*.list line for x86_64 (Arch) and aarch64 (Arch
Linux ARM) the same way lib/pkg.sh does at install time, without needing an
Arch machine: it reads the real repo databases and the AUR.

    scripts/check-packages.py [--cache DIR]

Prints one table per architecture and exits 1 if any line resolves to
nothing AND has no @fallback. AUR existence is checked through the RPC,
because cgit keeps .SRCINFO pages for packages that were deleted.
"""

import argparse
import io
import json
import os
import re
import sys
import tarfile
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPOS = {
    "x86_64": [f"https://geo.mirror.pkgbuild.com/{r}/os/x86_64/{r}.db" for r in ("core", "extra", "multilib")],
    "aarch64": [f"http://mirror.archlinuxarm.org/aarch64/{r}/{r}.db" for r in ("core", "extra", "alarm")],
}


def fetch(url, cache):
    path = os.path.join(cache, re.sub(r"[^A-Za-z0-9.]+", "_", url))
    if not os.path.exists(path):
        req = urllib.request.Request(url, headers={"User-Agent": "arch-dotfiles-check"})
        with urllib.request.urlopen(req, timeout=60) as r, open(path, "wb") as f:
            f.write(r.read())
    with open(path, "rb") as f:
        return f.read()


def repo_index(arch, cache):
    """name -> repo, plus provides -> name, from the sync databases."""
    names, provides = {}, {}
    for url in REPOS[arch]:
        repo = url.rsplit("/", 1)[1][:-3]
        with tarfile.open(fileobj=io.BytesIO(fetch(url, cache))) as t:
            # Newer databases keep everything in */desc; Arch Linux ARM still
            # splits PROVIDES out into */depends. Read both.
            for m in t.getmembers():
                if not m.name.endswith(("/desc", "/depends")):
                    continue
                text = t.extractfile(m).read().decode()
                fields = dict(
                    (k, v.split("\n")) for k, v in re.findall(r"%([A-Z]+)%\n(.*?)(?:\n\n|\Z)", text, re.S)
                )
                name = fields.get("NAME", [m.name.split("/")[0].rsplit("-", 2)[0]])[0]
                names[name] = repo
                for p in fields.get("PROVIDES", []):
                    provides.setdefault(re.split(r"[=<>]", p)[0], name)
    return names, provides


AUR = {}


def aur_archs(name):
    """Architectures an AUR package declares, or None if it isn't in the AUR.
    Existence comes from the RPC (cgit .SRCINFO pages outlive deleted
    packages); architectures from .SRCINFO. Network errors raise."""
    if name not in AUR:
        rpc = "https://aur.archlinux.org/rpc/v5/info?arg[]=" + urllib.parse.quote(name)
        with urllib.request.urlopen(rpc, timeout=30) as r:
            exists = json.load(r)["resultcount"] == 1
        if not exists:
            AUR[name] = None
        else:
            url = "https://aur.archlinux.org/cgit/aur.git/plain/.SRCINFO?h=" + urllib.parse.quote(name)
            with urllib.request.urlopen(url, timeout=30) as r:
                AUR[name] = set(re.findall(r"^\s*arch = (\S+)", r.read().decode(), re.M))
    return AUR[name]


def parse(path):
    for raw in open(path):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        only = None
        m = re.match(r"^(x86_64|aarch64):\s*(.*)$", line)
        if m:
            only, line = m.group(1), m.group(2)
        words = line.split()
        cands, fallback = [], None
        for i, w in enumerate(words):
            if w.startswith("@"):
                fallback = words[i:]
                break
            cands.append(w)
        yield only, cands, fallback


def resolve(arch, cands, idx):
    # Exact names only, like `pacman -Si` in lib/pkg.sh (no `provides`).
    names, _ = idx
    for c in cands:
        if c in names:
            return c, names[c]
        archs = aur_archs(c)
        if archs is not None and (arch in archs or "any" in archs):
            return c, "aur"
    return None, None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", default=os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")) + "/arch-dotfiles-check")
    args = ap.parse_args()
    os.makedirs(args.cache, exist_ok=True)

    failed = False
    lists = sorted(f for f in os.listdir(os.path.join(ROOT, "packages")) if f.endswith(".list"))
    for arch in ("x86_64", "aarch64"):
        idx = repo_index(arch, args.cache)
        print(f"\n=== {arch} ===")
        for lf in lists:
            for only, cands, fallback in parse(os.path.join(ROOT, "packages", lf)):
                label = " ".join(cands) or "-"
                if only and only != arch:
                    print(f"  {lf:13} {label:40} skip (only {only})")
                    continue
                pkg, src = resolve(arch, cands, idx) if cands else (None, None)
                if pkg:
                    note = "" if pkg == cands[0] else "  <- fallback"
                    print(f"  {lf:13} {label:40} {pkg} [{src}]{note}")
                elif fallback:
                    print(f"  {lf:13} {label:40} {' '.join(fallback[:2])}")
                else:
                    failed = True
                    print(f"  {lf:13} {label:40} MISSING")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
