#!/usr/bin/env python3
"""rolepod_config — the one reader of $HOME/.rolepod/config.json.

Usage (run as `python3 -I hooks/lib/rolepod_config.py <cmd>`):
  init   writes the default config to $HOME/.rolepod/config.json when nothing
         (file or symlink) is there; prints `wrote <path>` only when it wrote
  shell  prints two lines: gates=<off|soft|hard>  nudge=<on|off>
  pool   prints key=value lines: enabled=on|off, configured=yes|no (no = no
         `pool` key at all), then review= consult= critique= tier= implement=
         (a key that is not set is left out; no pool, cross-family off, or
         review=none -> `enabled=off` and `configured=` only)

Only the global file is read. A gates / nudge / pool key in the project file
(<git root, or cwd>/.rolepod/config.json) is ignored with one stderr line. A
broken file or an unknown value gives the default (soft, on, off) with one
stderr line. Always exits 0.
"""
import json
import os
import sys


BROKEN = []   # set when the global file exists but cannot be read

# The one copy of the default machine config (`init` writes it once; the pool
# lists are written but cross-family is off — only the user turns it on).
DEFAULT_CONFIG = """{
  "version": 1,
  "review": { "mode": "standard" },
  "gates": { "mode": "soft" },
  "nudge": { "enabled": true },
  "pool": {
    "cross-family": "off",
    "reviewer": { "review": "claude codex agy", "consult": "claude codex agy", "critique": "claude codex agy" },
    "implement": { "cli": "claude codex agy" }
  }
}
"""


def warn(msg):
    sys.stderr.write("rolepod-config: %s\n" % msg)


def project_root():
    d = os.getcwd()
    while True:
        if os.path.exists(os.path.join(d, ".git")):
            return d
        up = os.path.dirname(d)
        if up == d:
            return os.getcwd()
        d = up


def load_global():
    home = os.environ.get("HOME", "")
    path = os.path.join(home, ".rolepod", "config.json")
    if not home or not os.path.isfile(path):
        return {}
    try:
        with open(path) as f:
            d = json.load(f)
        if not isinstance(d, dict):
            raise ValueError("not an object")
        return d
    except Exception:
        BROKEN.append(path)
        warn("%r is unreadable; using the defaults" % path)
        return {}


def check_project():
    path = os.path.join(project_root(), ".rolepod", "config.json")
    if not os.path.isfile(path):
        return
    try:
        with open(path) as f:
            d = json.load(f)
    except Exception:
        return
    if isinstance(d, dict) and any(k in d for k in ("gates", "nudge", "pool")):
        warn("%r sets gates/nudge/pool; ignored (global config only)" % path)


def gates(cfg):
    g = cfg.get("gates")
    if g is None or not isinstance(g, dict) or "mode" not in g:
        if g is not None:
            warn("gates.mode is missing; using soft")
        return "soft"
    if g["mode"] in ("off", "soft", "hard"):
        return g["mode"]
    warn("gates.mode is not off|soft|hard; using soft")
    return "soft"


def nudge(cfg):
    n = cfg.get("nudge")
    if n is None or not isinstance(n, dict) or "enabled" not in n:
        if n is not None:
            warn("nudge.enabled is missing; using on")
        return "on"
    if isinstance(n["enabled"], bool):
        return "on" if n["enabled"] else "off"
    warn("nudge.enabled is not true|false; using on")
    return "on"


def clean(v):
    """A member string: one line, no control characters."""
    if not isinstance(v, str):
        return None
    v = " ".join(v.split())
    return v or None


def pool(cfg):
    p = cfg.get("pool")
    if p is None:
        return ["enabled=off"]
    if not isinstance(p, dict):
        warn("pool is not an object; pool off")
        return ["enabled=off"]
    vals = {}
    rev = p.get("reviewer")
    imp = p.get("implement")
    if rev is not None and not isinstance(rev, dict):
        warn("pool.reviewer is not an object; ignored")
    if isinstance(rev, dict):
        for k in ("review", "consult", "critique", "tier"):
            if k in rev and not isinstance(rev[k], str):
                warn("pool.reviewer.%s is not a string; ignored" % k)
            v = clean(rev.get(k))
            if v:
                vals[k] = v
    if imp is not None and not isinstance(imp, dict):
        warn("pool.implement is not an object; ignored")
    if isinstance(imp, dict):
        if "cli" in imp and not isinstance(imp["cli"], str):
            warn("pool.implement.cli is not a string; ignored")
        v = clean(imp.get("cli"))
        if v:
            vals["implement"] = v
    if "cross-family" in p:
        sw = p["cross-family"]
        if sw == "off":
            return ["enabled=off"]
        if sw != "on":
            warn("pool.cross-family is not on|off; pool off")
            return ["enabled=off"]
    elif not vals:
        return ["enabled=off"]
    if vals.get("review") == "none" or not vals:
        return ["enabled=off"]
    out = ["enabled=on"]
    for k in ("review", "consult", "critique", "tier", "implement"):
        if k in vals:
            out.append("%s=%s" % (k, vals[k]))
    return out


def init():
    """Write the defaults to $HOME/.rolepod/config.json only when nothing (no
    file, no symlink, dangling included) is there. Prints `wrote <path>` when
    it wrote; silent on every other outcome, including any error."""
    try:
        home = os.environ.get("HOME", "")
        if not home:
            return
        d = os.path.join(home, ".rolepod")
        path = os.path.join(d, "config.json")
        if os.path.lexists(path):
            return
        os.makedirs(d, exist_ok=True)
        fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644)
        with os.fdopen(fd, "w") as f:
            f.write(DEFAULT_CONFIG)
        sys.stdout.write("wrote %s\n" % path)
    except Exception:
        pass


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "shell"
    if cmd == "init":
        init()
        return 0
    try:
        cfg = load_global()
        check_project()
        if cmd == "pool":
            lines = pool(cfg)
            # configured: is there a `pool` key at all (a deliberately off pool is "yes")
            lines.insert(1, "configured=" + ("yes" if cfg.get("pool") is not None or BROKEN else "no"))
        else:
            lines = ["gates=" + gates(cfg), "nudge=" + nudge(cfg)]
    except Exception:
        warn("internal error; using the defaults")
        lines = ["enabled=off", "configured=yes"] if cmd == "pool" else ["gates=soft", "nudge=on"]
    sys.stdout.write("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
