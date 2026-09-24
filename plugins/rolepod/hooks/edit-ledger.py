#!/usr/bin/env python3
"""rolepod edit ledger — CLI-neutral edit evidence for the commit gate (v2.134.0).

Every CLI's edit hook appends one line per edited file to
    <git root>/.rolepod/evidence/edits.jsonl
    {"t": <epoch>, "ts": "<iso utc>", "cli": "...", "path": "<repo-relative>",
     "kind": "test" | "risk" | "other", "agent": "<agent_type or ''>"}
and the gates (precommit-gate.sh, gate-reminder.sh, the opencode plugin) count
`test` / `risk` lines since the last commit — the same window and the same
classification the Claude transcript scan uses (hooks/lib/session_state.py:
test wins, risk = high-risk path AND code file), so a session driven from Codex,
Cursor, Antigravity or opencode carries the same evidence a Claude session does.

Standalone on purpose: no lib import, python3 -I, every failure exits 0 in
silence (a ledger must never block or slow an edit).

    edit-ledger.py append-stdin <cli>              Claude-shape stdin (tool_name /
                                                   tool_input incl. apply_patch, cwd,
                                                   agent_type); non-edit tools → no-op
    edit-ledger.py append <cli> <path>... [--cwd D] [--agent A]
    edit-ledger.py count <since_epoch|''> [--cwd D]   → "TEST_EDITS HIGH_RISK_EDITS"
"""
import json
import os
import re
import subprocess
import sys
import time

# ── classification — byte-identical to hooks/lib/session_state.py (pinned by
# tests/static/lean-surface.sh; edit both or neither) ────────────────────────
HIGH_RISK_PATH = re.compile(
    r"(^|/|_)"
    r"(auth|authn|authz|authentication|authorization|"
    r"billing|payment|payments|migration|migrations|"
    r"credit|credits|permission|permissions|secret|secrets|"
    r"crypto|cryptography|token|tokens|oauth|jwt|sso|saml|"
    r"webhook|webhooks|stripe|paypal|charge|charges|"
    r"invoice|invoices|deletion|deletions|erasure|gdpr|security)"
    r"(/|\.|_|$)",
    re.IGNORECASE,
)

TEST_FILE = re.compile(
    r"(^|/)("
    r"test|tests|__tests__|spec|specs|e2e"
    r")/.*|"
    r"\.(test|spec)\.(ts|tsx|js|jsx|mjs|cjs|py|go|rs|rb|java|kt|swift|cs|php)$|"
    # Case-SENSITIVE (local `(?-i:...)`, the whole pattern is compiled with
    # re.IGNORECASE): the commit gate's own filename filter
    # (precommit-gate.sh HIGH_RISK= line) has no -i, so a lowercase-`test`
    # collision inside an unrelated word (AppAttest.swift, Latest.java,
    # Contest.cs) must not be exempted here while the gate still calls it
    # high-risk — reviewed 2026-09-24, MAJOR-1.
    r"(?-i:(^|/)(test_[^/]*|[^/]*_test|[^/]*_spec)\.(py|go|rs|rb|php)$)|"
    r"(?-i:(^|/)[^/]*Tests?\.(java|kt|cs|swift|php|scala)$)",
    re.IGNORECASE,
)

CODE_FILE = re.compile(
    r"\.(ts|tsx|js|jsx|py|go|rs|rb|java|kt|swift|cs|cpp|c|h|hpp|php|lua|sh|bash)$",
    re.IGNORECASE,
)

EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit", "apply_patch"}
MAX_BYTES = 512 * 1024      # rotate past this …
KEEP_LINES = 2000           # … keeping the newest lines


def git_root(cwd):
    try:
        r = subprocess.run(["git", "-C", cwd or ".", "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True, timeout=3)
        return r.stdout.strip() if r.returncode == 0 and r.stdout.strip() else None
    except Exception:
        return None


# .rolepod/risk-paths override — same parse as session_state._load_risk_overrides
# (bare/`+` ADD, `-` EXCLUDE, `#` comment, bad regex skipped, missing file =
# built-ins only), but read from the git root of the EDIT's cwd (the `root`
# already resolved by the caller via git_root(cwd)), not the process cwd —
# a ledger append run from another repo with --cwd pointing here must still
# honour THIS repo's file. Cached per root: one edit-ledger process handles
# one append call, but the cache keeps a repeated classify() cheap.
_RISK_OVERRIDE_CACHE = {}


def _load_risk_overrides(root):
    if not root:
        return [], []
    if root in _RISK_OVERRIDE_CACHE:
        return _RISK_OVERRIDE_CACHE[root]
    add, excl = [], []
    try:
        with open(os.path.join(root, ".rolepod", "risk-paths"), encoding="utf-8") as f:
            for ln in f:
                ln = ln.split("#", 1)[0].strip()
                if not ln:
                    continue
                try:
                    if ln.startswith("-"):
                        excl.append(re.compile(ln[1:], re.IGNORECASE))
                    else:
                        add.append(re.compile(ln.lstrip("+"), re.IGNORECASE))
                except re.error:
                    continue
    except Exception:
        pass
    _RISK_OVERRIDE_CACHE[root] = (add, excl)
    return add, excl


def classify(path, root=None):
    if TEST_FILE.search(path):
        return "test"
    add, excl = _load_risk_overrides(root)
    # CODE_FILE gates a risk-paths ADD hit too, same as a built-in hit — the
    # session_state.py call site applies is_code_file() uniformly over
    # is_high_risk_path() (built-ins + ADD overrides alike); an ADD pattern
    # bypassing it here would count a non-code file (e.g. a doc) as a risk
    # edit that session_state's own tally never would — reviewed
    # 2026-09-24, MINOR-4.
    path_risk = HIGH_RISK_PATH.search(path) or any(p.search(path) for p in add)
    hit = bool(path_risk) and bool(CODE_FILE.search(path))
    if hit and any(p.search(path) for p in excl):
        return "other"
    return "risk" if hit else "other"


def relative(root, path):
    """Repo-relative when the path sits under the root — compared on realpaths, so
    /var/... (a CLI's spelling) and /private/var/... (git's toplevel) still match."""
    try:
        rr, rp = os.path.realpath(root), os.path.realpath(path)
        if rp.startswith(rr + os.sep):
            return rp[len(rr) + 1:]
    except Exception:
        pass
    if root and path.startswith(root + "/"):
        return path[len(root) + 1:]
    return path


def paths_from_stdin(d):
    if (d.get("tool_name") or "") not in EDIT_TOOLS:
        return []
    ti = d.get("tool_input") or {}
    p = ti.get("file_path") or ti.get("notebook_path") or ti.get("path") or ""
    if p:
        return [p]
    body = ti.get("input") or ti.get("patch") or ""
    return [m.strip() for m in re.findall(r"\*\*\* (?:Add|Update|Delete) File: (.+)", body)]


def append(root, cli, paths, agent=""):
    paths = [p for p in paths if p]
    if not root or not paths:
        return
    ev = os.path.join(root, ".rolepod", "evidence")
    os.makedirs(ev, exist_ok=True)
    ledger = os.path.join(ev, "edits.jsonl")
    now = time.time()
    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now))
    with open(ledger, "a", encoding="utf-8") as f:
        for p in paths:
            rel = relative(root, p)
            # classify() on the REPO-RELATIVE path, not the raw (often
            # absolute) one: a `.rolepod/risk-paths` line anchored with `^`
            # (e.g. `-^design_tokens/`) must anchor to the repo root, the
            # same place session_state._load_risk_overrides anchors it —
            # reviewed 2026-09-24, MINOR-2.
            f.write(json.dumps({"t": round(now, 3), "ts": ts, "cli": cli,
                                "path": rel, "kind": classify(rel, root),
                                "agent": agent or ""}, ensure_ascii=False) + "\n")
    try:
        if os.path.getsize(ledger) > MAX_BYTES:
            with open(ledger, encoding="utf-8", errors="replace") as f:
                lines = f.readlines()
            with open(ledger, "w", encoding="utf-8") as f:
                f.writelines(lines[-KEEP_LINES:])
    except OSError:
        pass


def count(root, since):
    test = risk = 0
    if not root:
        return test, risk
    ledger = os.path.join(root, ".rolepod", "evidence", "edits.jsonl")
    try:
        with open(ledger, encoding="utf-8", errors="replace") as f:
            for line in f:
                try:
                    d = json.loads(line)
                except Exception:
                    continue
                if since is not None and float(d.get("t") or 0) < since:
                    continue
                k = d.get("kind")
                if k == "test":
                    test += 1
                elif k == "risk":
                    risk += 1
    except OSError:
        pass
    return test, risk


def _opt(args, name, default=""):
    if name in args:
        i = args.index(name)
        val = args[i + 1] if i + 1 < len(args) else default
        del args[i:i + 2]
        return val
    return default


def main(argv):
    if not argv:
        return
    mode, args = argv[0], list(argv[1:])
    if mode == "append-stdin":
        cli = args[0] if args else "claude"
        try:
            d = json.load(sys.stdin)
        except Exception:
            return
        if not isinstance(d, dict):
            return
        paths = paths_from_stdin(d)
        if not paths:
            return
        if cli == "claude" and (d.get("tool_name") or "") == "apply_patch":
            cli = "codex"   # the same script ships in the Codex plugin
        append(git_root(d.get("cwd") or os.getcwd()), cli, paths, d.get("agent_type") or "")
    elif mode == "append":
        cwd = _opt(args, "--cwd", os.getcwd())
        agent = _opt(args, "--agent", "")
        if not args:
            return
        append(git_root(cwd), args[0], args[1:], agent)
    elif mode == "count":
        since_raw = args[0] if args else ""
        cwd = _opt(args, "--cwd", os.getcwd())
        since = None
        try:
            since = float(since_raw) if since_raw not in ("", "0", "none") else None
        except ValueError:
            since = None
        t, r = count(git_root(cwd), since)
        print(f"{t} {r}")


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except Exception:
        if len(sys.argv) > 1 and sys.argv[1] == "count":
            print("0 0")
    sys.exit(0)
