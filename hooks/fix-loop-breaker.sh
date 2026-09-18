#!/bin/bash
# fix-loop-breaker — PostToolUse(Bash): mechanical counter for fix→fail loops.
#
# Compensates (recorded per decay-cadence practice): Leads below sonnet-class
# instruction-following cannot self-count failed attempts — every retry feels
# like a fresh attempt. Real case 2026-08-21: a Codex terra Lead looped a
# failing fix for many rounds with all hooks enabled; the prose stops
# (AGENTS.md hard-stop line + debug-issue Iron Rule #5) sat in context and
# were ignored. Prose asks the model to count; this hook counts for it and
# injects the STOP text at the exact moment the loop is about to take its
# next lap. Strong Leads (sonnet+) already obey the prose — for them the
# nudge is redundant and rarely fires.
#
# Mechanics: fingerprint = sha1 of the whitespace-normalized command. A
# non-zero exit increments that fingerprint's consecutive-fail count; a clean
# run resets it. At >= 3 consecutive fails, inject additionalContext telling
# the Lead to apply debug-issue Iron Rule #5 (stop fixing, hypothesis ledger,
# ONE cross-model advisor opinion or escalate). Advisory only — never blocks.
#
# Scope limit (stated so a silent gap is not assumed covered): only
# identical-command loops (the rerun-the-repro loop) are counted. A loop that
# mutates its command every round evades the counter — accepted; prose covers
# models strong enough to vary their probes, this net exists for the weak
# ones re-running the same failing command.
#
# Second duty (v2.149.0) — post-commit worktree reminder. Task owners build
# in .worktrees/<task>/ and the Lead merges; a user who never learned
# `git worktree remove` accumulates a checkout per task until the disk is
# full. After every successful `git commit` this hook lists the rolepod-shaped
# worktrees left behind — <root>/.worktrees/*, <root>/worktrees/*, or the
# sibling a generated brief creates (../<root-name>-wt-<task>); never
# harness-owned paths, never the current checkout — tags each merged /
# unmerged (+N commits) / in use (a live sibling lock), and says the cleanup
# order. additionalContext for the model; on Claude also systemMessage so the
# user sees it without a relay (opencode forwards additionalContext only).
# Runs after the loop counter wrote its state, under one 1 s deadline.
#
# Fail-open everywhere: no JSON, no session_id, unwritable state → exit 0.

set -uo pipefail

INPUT=$(cat 2>/dev/null || true)
[ -n "$INPUT" ] || exit 0

printf '%s' "$INPUT" | python3 -I -c '
import hashlib, json, os, re, sys, tempfile

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

if (d.get("tool_name") or "") != "Bash":
    sys.exit(0)
cmd = ((d.get("tool_input") or {}).get("command") or "").strip()
if not cmd:
    sys.exit(0)

notes = []
sysmsg = None

# ── fix→fail loop counter (runs first: its state write must never wait on git) ──
resp = d.get("tool_response")
text = resp if isinstance(resp, str) else json.dumps(resp or {})

# Exit-code extraction: structured field when the CLI provides one, else the
# "Exit code N" line a failing Bash result carries. No signal at all → treat
# as success (fail-open: never count what cannot be proven a failure).
code = None
interrupted = False
if isinstance(resp, dict):
    if resp.get("interrupted") is True:
        interrupted = True  # user cancel, not a failure
    for k in ("exitCode", "exit_code", "returnCode", "code"):
        v = resp.get(k)
        if isinstance(v, int):
            code = v
            break
if code is None:
    m = re.search(r"[Ee]xit code:? (\d+)", text)
    if m:
        code = int(m.group(1))
failed = code is not None and code != 0

sid = re.sub(r"[^A-Za-z0-9_-]", "", str(d.get("session_id") or ""))[:64]
if sid and not interrupted:
    state_path = os.path.join(tempfile.gettempdir(), "rolepod-loopbreak-%s.json" % sid)
    try:
        with open(state_path) as f:
            state = json.load(f)
        if not isinstance(state, dict):
            state = {}
    except Exception:
        state = {}

    fp = hashlib.sha1(" ".join(cmd.split()).encode()).hexdigest()[:16]
    prev = state.get(fp, 0)
    n = (prev if isinstance(prev, int) else 0) + 1 if failed else 0
    state[fp] = n
    if len(state) > 50:
        for k in list(state)[: len(state) - 50]:
            del state[k]
    try:
        with open(state_path, "w") as f:
            json.dump(state, f)
    except Exception:
        pass

    if n >= 3:
        notes.append(
            "LOOP BREAKER: this exact command failed %d times in a row, no pass between. "
            "STOP editing-and-retrying. Do: (1) stop fixing; (2) write the hypothesis "
            "ledger — what you believed, what each attempt changed, why it failed; (3) ONE "
            "cross-family consult (`rolepod-cross-family --kind consult --brief "
            "<ledger.md>`) or escalate to the user with the ledger. Same failure twice = "
            "wrong model of the bug."
            % n
        )

# ── post-commit worktree reminder (v2.149.0) — after the counter wrote its
# state; ONE 1 s deadline for the whole listing (Codex gives this hook 5 s,
# the opencode runCore 3 s), a failed or interrupted commit never reports.
GIT_COMMIT_RX = re.compile(r"(^|[;&|(]\s*|\s)(sudo\s+(-\S+\s+)*)?git\s+((-C|-c)\s+\S+\s+|--no-pager\s+)*commit\b")
mcommit = GIT_COMMIT_RX.search(cmd)
if mcommit and not failed and not interrupted:
    try:
        import subprocess, time
        deadline = time.monotonic() + 1.0
        mc = re.search(r"-C\s+(\S+)", mcommit.group(0))
        gdir = mc.group(1).strip("\x27\x22") if mc else None   # git -C <dir> commit: list THAT repo
        def git(*a, cwd=None):
            left = deadline - time.monotonic()
            if left <= 0:
                raise TimeoutError("deadline")
            return subprocess.run(["git", *a], capture_output=True, text=True, timeout=min(left, 1.0), cwd=cwd or gdir)
        common = git("rev-parse", "--git-common-dir").stdout.strip()
        if common and gdir and not os.path.isabs(common):
            common = os.path.join(gdir, common)
        common = os.path.realpath(common) if common else ""
        root = os.path.dirname(common) if os.path.basename(common) == ".git" else ""
        if root:
            blocks = [b for b in git("worktree", "list", "--porcelain").stdout.strip().split("\n\n") if b.strip()]
            cwd = os.path.realpath(gdir or os.getcwd())
            main_head = git("rev-parse", "HEAD", cwd=root).stdout.strip()
            locks = os.path.join(os.path.expanduser("~"), ".rolepod", "session-locks")
            items = []
            prunable = 0
            cut = False
            for b in blocks[1:]:
                f = {}
                for line in b.splitlines():
                    k, _, v = line.partition(" ")
                    f[k] = v
                raw = f.get("worktree", "")
                p = os.path.realpath(raw)
                # rolepod-shaped only: <root>/.worktrees/*, <root>/worktrees/*, or the
                # sibling a generated task brief creates (../<root-name>-wt-<task>).
                sibling = os.path.dirname(p) == os.path.dirname(root) and os.path.basename(p).startswith(os.path.basename(root) + "-wt-")
                if not (p.startswith(root + "/.worktrees/") or p.startswith(root + "/worktrees/") or sibling):
                    continue
                if "prunable" in f:
                    prunable += 1
                    continue
                if p == cwd or cwd.startswith(p + "/"):
                    continue
                head = f.get("HEAD", "")
                in_use = False
                for cand in {raw, p}:
                    ld = os.path.join(locks, hashlib.sha256(cand.encode()).hexdigest()[:16])
                    try:
                        now = time.time()
                        in_use = in_use or any(x.endswith(".lock") and now - os.path.getmtime(os.path.join(ld, x)) < 1800 for x in os.listdir(ld))
                    except Exception:
                        pass
                try:
                    if in_use:
                        tag = "in use"
                    elif head and (git("merge-base", "--is-ancestor", head, "HEAD").returncode == 0
                                   or (main_head and git("merge-base", "--is-ancestor", head, main_head).returncode == 0)):
                        tag = "merged"
                    else:
                        ahead = git("rev-list", "--count", "HEAD.." + head).stdout.strip() if head else ""
                        tag = "unmerged, +%s" % (ahead or "?")
                except (TimeoutError, subprocess.TimeoutExpired):
                    cut = True
                    break
                items.append((os.path.relpath(p, root), tag))
            if items or prunable:
                shown = ", ".join("%s (%s)" % it for it in items[:3])
                more = " +%d more" % (len(items) - 3) if len(items) > 3 else ""
                if cut:
                    more += " (list cut at 1 s, git worktree list shows the rest)"
                pr = " %d prunable entr%s (directory gone)." % (prunable, "y" if prunable == 1 else "ies") if prunable else ""
                wt = ("WORKTREES LEFT: %d rolepod worktree(s) after this commit: %s%s.%s "
                      "Fix: merged -> git worktree remove <path>, then git branch -d <branch>; unmerged -> finish or discard first; "
                      "then git worktree prune. Exception: in use = a live sibling session builds there, leave it."
                      % (len(items), shown, more, pr))
                notes.append(wt)
                sysmsg = wt
    except Exception:
        pass

if not notes:
    sys.exit(0)
out = {"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": "\n\n".join(notes)}}
if sysmsg:
    out["systemMessage"] = sysmsg
print(json.dumps(out))
' 2>/dev/null || true
exit 0
