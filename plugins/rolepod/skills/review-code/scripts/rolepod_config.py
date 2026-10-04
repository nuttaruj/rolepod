#!/usr/bin/env python3
"""rolepod_config — the one reader of $HOME/.rolepod/config.json.

Usage (run as `python3 -I hooks/lib/rolepod_config.py <cmd>`):
  init   writes the default config to $HOME/.rolepod/config.json when it is
         missing, unreadable JSON or the old format (top-level review / gates /
         nudge, or no workflow.mode), keeping any `pool`; no backup; prints
         `wrote <path> (<missing|unreadable|old format>)` only when it wrote
  mode   prints stable key=value metadata for the effective workflow profile
  shell  prints two lines: gates=<off|soft|hard>  nudge=<on|off>
  pool   prints key=value lines: enabled=on|off, configured=yes|no (no = no
         `pool` key at all), then review= consult= critique= tier= implement=
         (a key that is not set is left out; no pool, cross-family off, or
         review=none -> `enabled=off` and `configured=` only)

Workflow mode resolves from the project file then the global file. Legacy
review/gates/nudge keys do not affect the profile. Pool remains global-only.
Broken JSON or an invalid workflow value uses the standard profile with one
stderr warning. Always exits 0.
"""
import json
import os
import sys


BROKEN = []   # set when the global file exists but cannot be read

# The one copy of the default machine config (`init` writes it once; the pool
# lists are written but cross-family is off — only the user turns it on).
DEFAULT_CONFIG = """{
  "version": 1,
  "workflow": { "mode": "lite" },
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
    explicit = os.environ.get("ROLEPOD_PROJECT_ROOT")
    start = os.path.abspath(explicit if explicit else os.getcwd())
    d = start
    while True:
        if os.path.exists(os.path.join(d, ".git")):
            return d
        up = os.path.dirname(d)
        if up == d:
            return start
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
    if isinstance(d, dict) and "pool" in d:
        warn("%r project pool is ignored; global config only" % path)


def load_project():
    path = os.path.join(project_root(), ".rolepod", "config.json")
    if not os.path.isfile(path):
        return {}
    try:
        with open(path) as f:
            d = json.load(f)
        if not isinstance(d, dict):
            raise ValueError("not an object")
        return d
    except Exception:
        return {"__broken__": True}


def selected_mode(project, global_cfg):
    if project.get("__broken__"):
        warn("project config is unreadable; using standard workflow mode")
        return "standard", "project", False
    for source, cfg in (("project", project), ("global", global_cfg)):
        if source == "global" and BROKEN:
            return "standard", "global", False
        if "workflow" not in cfg:
            continue
        w = cfg.get("workflow")
        v = w.get("mode") if isinstance(w, dict) else None
        if v in ("lite", "standard", "full"):
            return v, source, True
        warn("workflow.mode is not lite|standard|full; using standard")
        return "standard", source, True
    return "lite", "default", False


def effective(project, global_cfg):
    mode, source, modern = selected_mode(project, global_cfg)
    gates_value, nudge_value = {"lite": ("off", "on"), "standard": ("soft", "on"), "full": ("hard", "on")}[mode]
    review_value = "full" if mode == "full" else "standard"
    return mode, source, modern, gates_value, nudge_value, review_value, source


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
    """Write the defaults to $HOME/.rolepod/config.json only when the path is
    missing, the file is not valid JSON, or it is the old format (a top-level
    review / gates / nudge key, or no workflow.mode). A pool object is kept;
    no backup is made. Prints `wrote <path> (<missing|unreadable|old format>)`
    when it wrote; silent on every other outcome, including any error."""
    try:
        home = os.environ.get("HOME", "")
        if not home:
            return
        d = os.path.join(home, ".rolepod")
        path = os.path.join(d, "config.json")
        existing = None
        if not os.path.lexists(path):
            reason = "missing"
        elif not os.path.isfile(path):
            return   # a dangling symlink or a directory is never touched
        else:
            try:
                with open(path) as f:
                    existing = json.load(f)
            except (OSError, ValueError):   # ValueError covers bad JSON and bad UTF-8
                existing = None
                reason = "unreadable"
            else:
                w = existing.get("workflow") if isinstance(existing, dict) else None
                if (isinstance(existing, dict) and not any(k in existing for k in ("review", "gates", "nudge"))
                        and isinstance(w, dict) and "mode" in w):
                    return
                reason = "old format"
        os.makedirs(d, exist_ok=True)
        contents = DEFAULT_CONFIG
        if isinstance(existing, dict) and isinstance(existing.get("pool"), dict):
            replacement = json.loads(DEFAULT_CONFIG)
            replacement["pool"] = existing["pool"]
            contents = json.dumps(replacement, indent=2) + "\n"
        # Complete file or nothing: a concurrent reader or init never sees a
        # half-written config. A symlinked config is written through to its target.
        target = os.path.realpath(path) if reason != "missing" else path
        tmp = "%s.%d.tmp" % (target, os.getpid())
        fd = os.open(tmp, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644)
        try:
            with os.fdopen(fd, "w") as f:
                f.write(contents)
            if reason == "missing":
                os.link(tmp, target)   # fails if a concurrent init got there first
            else:
                os.replace(tmp, target)
        finally:
            try:
                os.unlink(tmp)
            except OSError:
                pass
        sys.stdout.write("wrote %s (%s)\n" % (path, reason))
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
        project = load_project()
        if cmd == "pool":
            lines = pool(cfg)
            # configured: is there a `pool` key at all (a deliberately off pool is "yes")
            lines.insert(1, "configured=" + ("yes" if cfg.get("pool") is not None or BROKEN else "no"))
        elif cmd == "review":
            _, _, _, _, _, review_value, review_source = effective(project, cfg)
            lines = [review_value, "source=" + review_source]
        elif cmd in ("shell", "mode"):
            mode, source, modern, gate_value, nudge_value, review_value, review_source = effective(project, cfg)
            lines = ["mode=" + mode, "source=" + source, "modern=" + ("yes" if modern else "no"), "gates=" + gate_value, "nudge=" + nudge_value, "review=" + review_value, "review-source=" + review_source]
            if cmd == "shell":
                lines = lines[3:5]
        else:
            _, _, _, gate_value, nudge_value, _, _ = effective(project, cfg)
            lines = ["gates=" + gate_value, "nudge=" + nudge_value]
    except Exception:
        warn("internal error; using the defaults")
        lines = ["enabled=off", "configured=yes"] if cmd == "pool" else ["gates=soft", "nudge=on"]
    sys.stdout.write("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
