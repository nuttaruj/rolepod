"""Route-nudge checker for hooks/claim-verify-nudge.sh (v2.98.0).

stdin: the UserPromptSubmit hook input JSON (prompt, transcript_path).
stdout: "stale" when the prompt is commission-shaped AND the repo's newest
`phase:"route"` line is older than the previous user prompt; "" otherwise.

Commission = an imperative aimed at the repo (fix / add / change / build ...
and the Thai equivalents). Question-shaped prompts (why / how / Thai question
particles) are R0 and never nudged. Freshness: the previous user prompt's
timestamp comes from the transcript tail; no transcript -> 30 minutes.
Not a git repo -> "". Thai words are written as \\u escapes: the repo's
CI keeps every tracked file ASCII/English-only.
"""
import datetime
import json
import os
import re
import subprocess
import sys

EN_COMMISSION = re.compile(
    r"(^|[^a-z])(fix|add|change|build|create|implement|refactor|remove|delete|update|"
    r"migrate|rename|make|write|ship|deploy|wire|continue|go ahead|do it|proceed)([^a-z]|$)",
    re.I,
)
TH_COMMISSION = [
    "\u0e41\u0e01\u0e49",                          # fix
    "\u0e40\u0e1e\u0e34\u0e48\u0e21",              # add
    "\u0e2a\u0e23\u0e49\u0e32\u0e07",              # create
    "\u0e17\u0e33",                                # do / make
    "\u0e25\u0e1a",                                # delete
    "\u0e40\u0e1b\u0e25\u0e35\u0e48\u0e22\u0e19",  # change
    "\u0e1b\u0e23\u0e31\u0e1a",                    # adjust
    "\u0e22\u0e49\u0e32\u0e22",                    # move
    "\u0e40\u0e02\u0e35\u0e22\u0e19",              # write
    "\u0e08\u0e31\u0e14\u0e01\u0e32\u0e23",        # handle it
    "\u0e25\u0e38\u0e22",                          # go
    "\u0e40\u0e2d\u0e32\u0e40\u0e25\u0e22",        # go ahead
    "\u0e44\u0e14\u0e49\u0e40\u0e25\u0e22",        # go ahead
    "\u0e15\u0e48\u0e2d\u0e40\u0e25\u0e22",        # continue
]
TH_QUESTION = [
    "\u0e17\u0e33\u0e44\u0e21",                    # why
    "\u0e22\u0e31\u0e07\u0e44\u0e07",              # how
    "\u0e2d\u0e22\u0e48\u0e32\u0e07\u0e44\u0e23",  # how
    "\u0e2d\u0e30\u0e44\u0e23",                    # what
    "\u0e43\u0e0a\u0e48\u0e44\u0e2b\u0e21",        # is it?
    "\u0e44\u0e2b\u0e21",                          # ? particle
    "\u0e2b\u0e25\u0e2d",                          # ? particle
    "\u0e40\u0e2b\u0e23\u0e2d",                    # ? particle
    "?",
]


def iso(ts):
    try:
        return datetime.datetime.fromisoformat(str(ts).replace("Z", "+00:00")).timestamp()
    except Exception:
        return None


def tail(path, n):
    with open(path, "rb") as f:
        size = os.path.getsize(path)
        f.seek(max(0, size - n))
        return f.read().decode("utf-8", "ignore")


def commission_shaped(prompt):
    if any(q in prompt for q in TH_QUESTION):
        return False
    if EN_COMMISSION.search(prompt):
        return True
    return any(w in prompt for w in TH_COMMISSION)


def main():
    try:
        d = json.load(sys.stdin)
    except Exception:
        d = {}
    prompt = str(d.get("prompt") or "")
    if not commission_shaped(prompt):
        print("")
        return
    root = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip()
    if not root:
        print("")
        return
    log = os.path.join(root, ".rolepod", "evidence", "phase-log.jsonl")
    route_ts = None
    if os.path.isfile(log):
        for line in tail(log, 262144).splitlines():
            if '"phase":"route"' not in line and '"phase": "route"' not in line:
                continue
            try:
                t = iso(json.loads(line).get("ts", ""))
            except Exception:
                t = None
            if t and (route_ts is None or t > route_ts):
                route_ts = t
    if route_ts is None:
        print("stale")
        return
    now = datetime.datetime.now(datetime.timezone.utc).timestamp()
    last_user = None
    tp = d.get("transcript_path") or ""
    if tp and os.path.isfile(tp):
        for line in tail(tp, 2097152).splitlines():
            if '"type":"user"' not in line and '"type": "user"' not in line:
                continue
            try:
                e = json.loads(line)
            except Exception:
                continue
            c = (e.get("message") or {}).get("content")
            if isinstance(c, list):
                if not any(isinstance(b, dict) and b.get("type") == "text" and not str(b.get("text", "")).startswith("<") for b in c):
                    continue
            elif isinstance(c, str):
                if c.startswith("<"):
                    continue
            else:
                continue
            t = iso(e.get("timestamp", "") or "")
            if t and now - t > 5:   # the prompt being submitted may already be in the transcript
                last_user = t
    if last_user is not None:
        print("" if route_ts > last_user else "stale")
    else:
        print("" if now - route_ts < 1800 else "stale")


if __name__ == "__main__":
    main()
