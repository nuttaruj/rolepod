"""Route-nudge checker + route recorder for hooks/claim-verify-nudge.sh
(v2.98.0) and hooks/session-lifecycle.sh --unlock (v2.105.0).

stdin: the hook input JSON (prompt, transcript_path).
stdout: "stale" when the prompt is commission-shaped AND the repo's newest
`phase:"route"` line is older than the previous user prompt; "" otherwise.
`--record`: no output; only the recorder runs (the Stop hook entry).

Commission = an imperative aimed at the repo (fix / add / change / build ...
and the Thai equivalents). Question-shaped prompts (why / how / Thai question
particles) are R0 and never nudged. Freshness: the previous user prompt's
timestamp comes from the transcript tail; no transcript -> 30 minutes.
Not a git repo -> "". Thai words are written as \\u escapes: the repo's
CI keeps every tracked file ASCII/English-only.

Recorder (v2.105.0): the router asks the Lead to state the tier in one line
(`-> <skill> . R2 . <reason>` inline, `Tier: R3` in the block). The manual
phase-log append it also asked for was written 0 times across every product
repo on this machine, so the nudge fired on every commission and `make stats`
had no tier distribution. Now the hook reads the turn's assistant text from
the transcript tail, finds that routing line and appends
{"ts","phase":"route","tier","skill","provenance":"hook-auto"} once per
turn: at Stop (the turn is complete) and again on the next commission prompt
as a fallback (an interrupted turn has no Stop). A turn that already has a
route line, manual or auto, is left alone. A line counts only in two
shapes, both at line start: a `Route:` / `Tier:` field (`**Route: R2 --
reason**`, `Tier: R3`) or the arrow form (`-> <skill> . R2 . reason`).
Ignored: fenced code, `<skill>` / `<reason>` placeholders, `R0-R4` /
`R3/R4` / `R3 | R4` ranges, `R3-B`-style labels, anything mid-line
(Cloudflare `D1 . R2 . cron` rows, review-finding numbers). A user prompt
with no timestamp is still the turn boundary; the dedupe then keys on the
routing message's own timestamp.
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

# Routing-line shapes, both anchored at LINE START (markdown prefix allowed):
#   field:  Route: R2 -> <skill> . <reason>   |  **Route: R3 -- same task**  |  Tier: R3
#   arrow:  -> <skill> . R2 . <reason>          (the pre-2.105 one-liner)
# Measured on 164k assistant lines across every local session: real routes
# are the field form (14); `Routing:` block 0; arrow one-liner 0; `. R2 .`
# mid-line (4) = Cloudflare R2 table rows; bare line-start R2 / R3-B (34) =
# phase labels and review-finding numbers. So: no bare shape, nothing
# mid-line, nothing inside a code fence, no template placeholder.
TIER_END = "(?![A-Za-z0-9_]|-[A-Za-z0-9])"                  # R2 yes, R2x / R3-B no
RANGE_RX = re.compile(r"R[0-4]\s*[-/|]\s*R[0-4]")           # R0-R4, R3/R4, R3 | R4 = quoted doctrine
FIELD_RX = re.compile("^[\\s*_`#>\\-]*(?:tier|route|routing|rigor)[\\s*_`]*[:=][\\s*_`]*R([1-4])" + TIER_END, re.I)
ARROW_RX = re.compile("^[\\s*_`#>\\-]*\u2192\\s*`?[a-z][a-z0-9-]{2,}`?\\s*\u00b7\\s*R([1-4])" + TIER_END)
PLACEHOLDER = ("<skill>", "<reason>", "<phase>")
SKILL_INLINE = re.compile("\u2192\\s*`?([a-z][a-z0-9-]{2,})`?\\s*\u00b7")
SKILL_BLOCK = re.compile("Routing:[^\\n]*?\u2192\\s*`?([a-z][a-z0-9-]{2,})`?")

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
    if "please continue from where you left off" in prompt.lower():
        return False   # harness auto-resume, handled by the hook itself
    if any(q in prompt for q in TH_QUESTION):
        return False
    if EN_COMMISSION.search(prompt):
        return True
    return any(w in prompt for w in TH_COMMISSION)


def git_root():
    return subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip()


def log_path(root):
    return os.path.join(root, ".rolepod", "evidence", "phase-log.jsonl")


def newest_route_ts(log):
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
    return route_ts


def real_user_prompt(e):
    """A user turn typed by the person: not a tool_result, not a harness block."""
    c = (e.get("message") or {}).get("content")
    if isinstance(c, list):
        return any(isinstance(b, dict) and b.get("type") == "text" and not str(b.get("text", "")).startswith("<") for b in c)
    if isinstance(c, str):
        return not c.startswith("<")
    return False


def find_route(text):
    """(tier, skill) from the LAST routing-shaped line of one assistant message, else None."""
    found = None
    fence = False
    for raw in text.splitlines():
        s = raw.strip()
        if s.startswith("```"):
            fence = not fence
            continue
        if fence or any(p in s for p in PLACEHOLDER):
            continue                             # quoted template, not a decision
        core = RANGE_RX.sub(" ", s)
        m = FIELD_RX.match(core) or ARROW_RX.match(core)
        if not m:
            continue
        sk = SKILL_INLINE.search(core)
        found = ("R" + m.group(1), sk.group(1) if sk else "")
    if found and not found[1]:
        blk = SKILL_BLOCK.search(text)
        if blk:
            found = (found[0], blk.group(1))
    return found

def record_route(d, log, now, settle):
    """Append the tier the Lead stated this turn to the phase-log, once per turn.

    settle: seconds a user prompt must be old to count as this turn's start
    (UserPromptSubmit: the prompt being submitted may already be in the
    transcript -> 5; Stop: everything is settled -> 0)."""
    tp = d.get("transcript_path") or ""
    if not tp or not os.path.isfile(tp):
        return
    turn = []           # (text, ts) assistant entries since the last real user prompt
    last_user = None
    saw_user = False
    for line in tail(tp, 2097152).splitlines():
        if '"isSidechain":true' in line or '"isSidechain": true' in line:
            continue
        try:
            e = json.loads(line)
        except Exception:
            continue
        typ = e.get("type")
        if typ == "user":
            if not real_user_prompt(e):
                continue
            t = iso(e.get("timestamp") or "")
            if t is not None and now - t <= settle:
                break       # the prompt being submitted: nothing after it is this turn
            turn = []
            last_user = t
            saw_user = True   # a prompt with no timestamp is still the boundary
        elif typ == "assistant":
            c = (e.get("message") or {}).get("content")
            parts = []
            if isinstance(c, list):
                parts = [str(b.get("text") or "") for b in c if isinstance(b, dict) and b.get("type") == "text"]
            elif isinstance(c, str):
                parts = [c]
            txt = "\n".join(p for p in parts if p)
            if txt:
                turn.append((txt, str(e.get("timestamp") or "")))
    if not saw_user or not turn:
        return
    found = None
    for txt, ts in turn:
        r = find_route(txt)
        if r:
            found = (r[0], r[1], ts)
    if not found:
        return
    tier, skill, ts = found
    ref = last_user if last_user is not None else iso(ts)
    newest = newest_route_ts(log)
    if newest is not None and (ref is None or newest >= ref):
        return              # this turn already has a route line (manual or auto)
    if iso(ts) is None:
        ts = datetime.datetime.fromtimestamp(now, datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    os.makedirs(os.path.dirname(log), exist_ok=True)
    with open(log, "a") as f:
        f.write(json.dumps({"ts": ts, "phase": "route", "tier": tier, "skill": skill,
                            "provenance": "hook-auto"}, separators=(",", ":")) + "\n")


def main():
    record_only = "--record" in sys.argv[1:]
    try:
        d = json.load(sys.stdin)
    except Exception:
        d = {}
    now = datetime.datetime.now(datetime.timezone.utc).timestamp()
    if record_only:
        root = git_root()
        if root:
            try:
                record_route(d, log_path(root), now, 0)
            except Exception:
                pass
        return
    prompt = str(d.get("prompt") or "")
    if not commission_shaped(prompt):
        print("")
        return
    root = git_root()
    if not root:
        print("")
        return
    log = log_path(root)
    try:
        record_route(d, log, now, 5)   # fallback for a turn that never reached Stop
    except Exception:
        pass
    route_ts = newest_route_ts(log)
    if route_ts is None:
        print("stale")
        return
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
            if not real_user_prompt(e):
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
