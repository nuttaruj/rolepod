#!/bin/bash
# bench-hooks — wall-time of every Claude-side hook on a representative
# payload (v2.128.0). Advisory: prints a table, never gates a test.
#
# Why: a hook runs on EVERY matching tool call, in the Lead and in every
# subagent, and nothing measured what that cost. Measured 2026-09-14 on a
# 7.9 MB transcript before this script existed: the PreToolUse Edit chain
# ran 523 ms per edit (worktree-guard 283, gate-reminder 136), the
# UserPromptSubmit chain 527 ms per prompt (claim-verify-nudge 471), Bash
# pre+post 241 ms — process spawns dominate (each `python3 -I -c` ≈ 30-50 ms).
# A 250-call subagent paid ~1 minute of hook wall-time. The signal worth
# guarding is the catastrophic class (a scan that grows with the transcript,
# a regex that backtracks), which shows up as seconds — so the table flags
# a median above SLOW_MS and a max above SPIKE_MS, and the sum per event is
# what a tool call actually pays.
#
# Fixture: a synthetic transcript (~SIZE_MB of assistant / user events with
# usage + one routing line) and a throwaway git repo, so the numbers do not
# depend on the machine's real sessions and never touch them. Runs are
# repeated RUNS times; the table shows the median and the max.
#
#   make bench-hooks                # RUNS=5 SIZE_MB=8
#   RUNS=1 SIZE_MB=2 bash scripts/bench-hooks.sh   # smoke
#   bash scripts/bench-hooks.sh --json             # machine-readable rows
set -uo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNS="${RUNS:-5}"; SIZE_MB="${SIZE_MB:-8}"; SLOW_MS="${SLOW_MS:-250}"; SPIKE_MS="${SPIKE_MS:-1000}"
JSON=0; [ "${1:-}" = "--json" ] && JSON=1
command -v python3 >/dev/null 2>&1 || { echo "bench-hooks: python3 required"; exit 2; }

REPO_DIR="$REPO_DIR" RUNS="$RUNS" SIZE_MB="$SIZE_MB" SLOW_MS="$SLOW_MS" SPIKE_MS="$SPIKE_MS" JSON="$JSON" python3 -I - <<'PY'
import json, os, shutil, statistics, subprocess, tempfile, time

REPO = os.environ["REPO_DIR"]; HOOKS = os.path.join(REPO, "hooks")
RUNS = int(os.environ["RUNS"]); SIZE = float(os.environ["SIZE_MB"])
SLOW = float(os.environ["SLOW_MS"]); SPIKE = float(os.environ["SPIKE_MS"]); JSON_OUT = os.environ["JSON"] == "1"

tmp = tempfile.mkdtemp(prefix="rolepod-bench-")
home = os.path.join(tmp, "home"); os.makedirs(home)
repo = os.path.join(tmp, "repo"); os.makedirs(os.path.join(repo, "src", "auth"))
subprocess.run(["git", "init", "-q", "."], cwd=repo, check=True)
subprocess.run(["git", "-c", "user.email=b@b", "-c", "user.name=b", "commit", "-q", "--allow-empty", "-m", "init"], cwd=repo, check=True)
open(os.path.join(repo, "src", "auth", "login.py"), "w").write("x = 1\n")
target = os.path.join(repo, "src", "auth", "login.py")

# Synthetic transcript: the shapes the tail-scan helpers look for — assistant
# messages with usage, tool_use blocks, a routing line, real user prompts.
tr = os.path.join(tmp, "transcript.jsonl")
row_u = {"type": "user", "timestamp": "2026-01-01T00:00:00.000Z", "message": {"role": "user", "content": "please do the thing"}}
row_r = {"type": "assistant", "timestamp": "2026-01-01T00:00:01.000Z", "message": {"role": "assistant", "model": "claude-opus-5",
         "content": [{"type": "text", "text": "Route: R3 (multi-file) -> implement-plan . bench"}], "usage": {"input_tokens": 1000, "cache_read_input_tokens": 200000, "cache_creation_input_tokens": 500, "output_tokens": 100}}}
row_e = {"type": "assistant", "timestamp": "2026-01-01T00:00:02.000Z", "message": {"role": "assistant", "model": "claude-opus-5",
         "content": [{"type": "tool_use", "id": "t1", "name": "Edit", "input": {"file_path": target, "old_string": "a", "new_string": "b"}}],
         "usage": {"input_tokens": 1000, "cache_read_input_tokens": 200000, "cache_creation_input_tokens": 500, "output_tokens": 100}}}
row_t = {"type": "user", "timestamp": "2026-01-01T00:00:03.000Z", "message": {"role": "user", "content": [{"type": "tool_result", "tool_use_id": "t1", "content": "ok " * 400}]}}
with open(tr, "w") as f:
    f.write(json.dumps(row_u) + "\n" + json.dumps(row_r) + "\n")
    block = json.dumps(row_e) + "\n" + json.dumps(row_t) + "\n"
    while f.tell() < SIZE * 1024 * 1024:
        f.write(block)
size_mb = os.path.getsize(tr) / 1e6

base = {"session_id": "bench-" + str(os.getpid()), "transcript_path": tr, "cwd": repo}
def P(**k): return json.dumps({**base, **k})
edit = {"file_path": target, "old_string": "a", "new_string": "b"}
agent = {"subagent_type": "rolepod:scout", "prompt": "map the repo"}
cases = [
  ("PreToolUse Bash",   "precommit-gate.sh",         P(hook_event_name="PreToolUse", tool_name="Bash", tool_input={"command": "ls -la"})),
  ("PreToolUse Bash",   "push-ref-check.sh",         P(hook_event_name="PreToolUse", tool_name="Bash", tool_input={"command": "ls -la"})),
  ("PreToolUse Bash",   "block-subagent-commit.sh",  P(hook_event_name="PreToolUse", tool_name="Bash", tool_input={"command": "ls -la"})),
  ("PostToolUse Bash",  "fix-loop-breaker.sh",       P(hook_event_name="PostToolUse", tool_name="Bash", tool_input={"command": "ls -la"}, tool_response={"stdout": "ok"})),
  ("PreToolUse Edit",   "worktree-guard.sh",         P(hook_event_name="PreToolUse", tool_name="Edit", tool_input=edit)),
  ("PreToolUse Edit",   "gate-reminder.sh",          P(hook_event_name="PreToolUse", tool_name="Edit", tool_input=edit)),
  ("PreToolUse Edit",   "subagent-write-scope.sh",   P(hook_event_name="PreToolUse", tool_name="Edit", tool_input=edit)),
  ("PreToolUse Agent",  "workflow-tier-nudge.sh",    P(hook_event_name="PreToolUse", tool_name="Agent", tool_input=agent)),
  ("PostToolUse Agent", "dispatch-auto-log.sh",      P(hook_event_name="PostToolUse", tool_name="Agent", tool_input=agent, tool_response="done")),
  ("UserPromptSubmit",  "claim-verify-nudge.sh",     P(hook_event_name="UserPromptSubmit", prompt="fix the login bug")),
]
env = {**os.environ, "HOME": home, "TMPDIR": tmp, "ROLEPOD_NUDGE_OFF": ""}
env.pop("ROLEPOD_NUDGE_OFF", None)
rows = []; per_event = {}
for ev, hook, payload in cases:
    path = os.path.join(HOOKS, hook)
    if not os.path.isfile(path):
        rows.append({"event": ev, "hook": hook, "median_ms": None, "max_ms": None, "note": "missing"}); continue
    ts = []
    for _ in range(RUNS):
        t0 = time.perf_counter()
        subprocess.run(["bash", path], input=payload, text=True, capture_output=True, cwd=repo, env=env)
        ts.append((time.perf_counter() - t0) * 1000)
    med = statistics.median(ts); mx = max(ts)
    flag = "SLOW" if med > SLOW else ("spike" if mx > SPIKE else "")
    rows.append({"event": ev, "hook": hook, "median_ms": round(med), "max_ms": round(mx), "note": flag})
    per_event[ev] = per_event.get(ev, 0) + med
shutil.rmtree(tmp, ignore_errors=True)

if JSON_OUT:
    print(json.dumps({"runs": RUNS, "transcript_mb": round(size_mb, 1), "rows": rows,
                      "per_event_ms": {k: round(v) for k, v in per_event.items()}}))
    raise SystemExit(0)
print("-- bench-hooks: %d run(s) per hook, synthetic transcript %.1f MB, throwaway git repo" % (RUNS, size_mb))
print("%-18s %-27s %9s %8s  %s" % ("event", "hook", "median ms", "max ms", "flag"))
for r in rows:
    if r["median_ms"] is None:
        print("%-18s %-27s %9s %8s  %s" % (r["event"], r["hook"], "-", "-", r["note"])); continue
    print("%-18s %-27s %9d %8d  %s" % (r["event"], r["hook"], r["median_ms"], r["max_ms"], r["note"]))
print("\nper tool call (sum of medians -- what one call of that shape pays):")
for ev, ms in per_event.items():
    print("  %-18s %6d ms" % (ev, ms))
slow = [r for r in rows if r.get("note") == "SLOW"]
if slow:
    print("\nSLOW = median above %d ms: %s. Fix: one python spawn per hook, tail-scan the transcript, no full-file reads per call." % (SLOW, ", ".join(r["hook"] for r in slow)))
PY
