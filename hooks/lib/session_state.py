#!/usr/bin/env python3
"""
Session-state inspector for rolepod hooks.

Claude Code passes `transcript_path` in every hook input. The transcript is
a JSONL log of every assistant message + tool use in the current session.
This script parses it to answer questions hooks need to enforce gates:

  - How many test files has Lead edited this session?
  - How many high-risk code files (auth/billing/etc.) has Lead edited?
  - Has Lead dispatched qa-tester / security-engineer / universal-reviewer?
  - How many parallel Agent spawns share the same path?

CLI: pass a hook-input JSON on stdin, request a query as argv[1]. Output is
plain stdout (number or yes/no), exit 0 on success, non-zero on parse error.

Designed to be cheap (single scan of transcript) and safe (graceful fallback
to 0 / "no" when transcript path missing or unreadable — hooks must not
block on infrastructure failure).
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path
from typing import Iterable

# Path patterns. These compile once at module load.

# High-risk path pattern. Tight — matches on full path segments (separated by
# `/`, `.`, `_`, or start/end), NOT arbitrary substrings. Loose substring
# matching produced false positives like `hooks/lib/session_state.py` (it
# contained "session") which is itself the session-inspector helper.
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
    r"\.(test|spec)\.(ts|tsx|js|jsx|py|go|rs|rb|java|kt|swift|cs|php)$|"
    r"(^|/)(test_|_test|.*_test)\.(py|go|rs)$",
    re.IGNORECASE,
)

# Source-code file extensions (used to count "code edits" vs docs/configs).
CODE_FILE = re.compile(
    r"\.(ts|tsx|js|jsx|py|go|rs|rb|java|kt|swift|cs|cpp|c|h|hpp|php|lua|sh|bash)$",
    re.IGNORECASE,
)

REVIEWER_AGENTS = {
    "qa-tester",
    "security-engineer",
    "universal-reviewer",
    "code-reviewer",
}

# Strong-class adversarial reviewers — the subset whose dispatch clears a
# HIGH-RISK commit gate. qa-tester is the balanced test floor by design
# (tier: balanced, hard model pin): its dispatch counts as review activity
# but NOT as the strong adversarial pass an R4 diff requires.
STRONG_REVIEWER_AGENTS = {
    "security-engineer",
    "universal-reviewer",
    "code-reviewer",
}

EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}

# Subagent-spawn tools. Claude Code has used both names across versions;
# match either so reviewer counting does not depend on the CLI version.
AGENT_TOOLS = {"Agent", "Task"}

# ── Model class (v2.47.0) ───────────────────────────────────────────────
# Family word → class. Only the FAMILY is matched (haiku / sonnet / opus…),
# never a version, so "claude-sonnet-5" → "claude-sonnet-6" changes nothing.
# Unknown family (a future tier, a gateway id, "<synthetic>") → "unknown".
# Hooks that UPGRADE act only on the KNOWN-LOW classes, so an unknown Lead is
# left untouched — the failure mode is "no upgrade" (today's behavior), never
# a downgrade of a model stronger than the alias we would write.
MODEL_CLASS = (
    (re.compile(r"haiku", re.IGNORECASE), "cheap"),
    (re.compile(r"sonnet", re.IGNORECASE), "balanced"),
    (re.compile(r"opus|fable|mythos", re.IGNORECASE), "strong"),
)
LOW_CLASSES = {"cheap", "balanced"}

# Strong-tier roles rendered `model: inherit` on Claude (merge-agent.py keeps
# them inherit so a fable-class Lead is not pinned DOWN to opus). On a
# known-low Lead that inherit is a silent downgrade of the adversarial pass —
# the dispatch hook writes the strong alias into the Agent call instead.
# system-architect is deliberately absent: cohesion-contract-check may deny a
# parallel architect spawn, and hook-decision precedence is undocumented, so
# it gets a nudge, not a rewrite.
STRONG_ROLE_AGENTS = {"security-engineer", "universal-reviewer"}
STRONG_ALIAS = "opus"


def model_class(name: str | None) -> str:
    for rx, cls in MODEL_CLASS:
        if rx.search(name or ""):
            return cls
    return "unknown"


def lead_model(transcript_path: str, tail_bytes: int = 262144) -> str:
    """Model of the LAST assistant turn in the transcript — the Lead's current
    model (or the dispatching subagent's, when a hook fires inside one).
    Tail-scan: read the last `tail_bytes`, walk lines backwards, grow ×4
    until found or the file is exhausted. '' when unknown / unreadable."""
    if not transcript_path or not os.path.isfile(transcript_path):
        return ""
    try:
        size = os.path.getsize(transcript_path)
        with open(transcript_path, "rb") as f:
            while True:
                start = max(0, size - tail_bytes)
                f.seek(start)
                chunk = f.read(size - start)
                lines = chunk.split(b"\n")
                if start > 0:
                    lines = lines[1:]  # first line may be a partial record
                for raw in reversed(lines):
                    if b'"assistant"' not in raw or b'"model"' not in raw:
                        continue
                    try:
                        ev = json.loads(raw)
                    except Exception:
                        continue
                    if ev.get("type") != "assistant":
                        continue
                    m = (ev.get("message") or {}).get("model") or ""
                    if m and m != "<synthetic>":
                        return m
                if start == 0:
                    return ""
                tail_bytes *= 4
    except Exception:
        return ""


def _load_hook_input() -> dict:
    raw = sys.stdin.read() or "{}"
    try:
        return json.loads(raw)
    except Exception:
        return {}


def _iter_transcript_events(transcript_path: str) -> Iterable[dict]:
    """Yield each JSONL event from the transcript. Silent on read failure."""
    if not transcript_path or not os.path.isfile(transcript_path):
        return
    try:
        with open(transcript_path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    yield json.loads(line)
                except Exception:
                    continue
    except Exception:
        return


def last_context_tokens(transcript_path: str, tail_bytes: int = 262144) -> int:
    """Context size of the Lead's LAST turn = input + cache_read + cache_creation
    of the newest assistant message that carries `usage`. This is what EVERY
    subsequent turn re-reads (and pays for) before doing anything. 0 when
    unknown. Same tail-scan discipline as lead_model."""
    if not transcript_path or not os.path.isfile(transcript_path):
        return 0
    try:
        size = os.path.getsize(transcript_path)
        with open(transcript_path, "rb") as f:
            while True:
                start = max(0, size - tail_bytes)
                f.seek(start)
                lines = f.read(size - start).split(b"\n")
                if start > 0:
                    lines = lines[1:]
                for raw in reversed(lines):
                    if b'"assistant"' not in raw or b'"usage"' not in raw:
                        continue
                    try:
                        ev = json.loads(raw)
                    except Exception:
                        continue
                    if ev.get("type") != "assistant":
                        continue
                    u = (ev.get("message") or {}).get("usage") or {}
                    tot = int(u.get("input_tokens") or 0) + int(u.get("cache_read_input_tokens") or 0) \
                        + int(u.get("cache_creation_input_tokens") or 0)
                    if tot > 0:
                        return tot
                if start == 0:
                    return 0
                tail_bytes *= 4
    except Exception:
        return 0


def dispatch_rounds_this_turn(transcript_path: str, tail_bytes: int = 262144) -> int:
    """How many ASSISTANT MESSAGES since the last real user prompt carried an
    Agent/Task tool_use — i.e. how many times the Lead has already been the
    coordinator round-trip in this turn (dispatch → wait → re-read the whole
    context → dispatch again). Parallel dispatches inside ONE message count
    once (that is fan-out, no extra round-trip). Tail-scan backwards to the
    last user event whose content is a prompt (string or text block) — tool
    results and meta events do not end the turn. 0 when unknown."""
    if not transcript_path or not os.path.isfile(transcript_path):
        return 0
    try:
        size = os.path.getsize(transcript_path)
        with open(transcript_path, "rb") as f:
            while True:
                start = max(0, size - tail_bytes)
                f.seek(start)
                lines = f.read(size - start).split(b"\n")
                if start > 0:
                    lines = lines[1:]
                rounds = 0
                for raw in reversed(lines):
                    if b'"type"' not in raw:
                        continue
                    try:
                        ev = json.loads(raw)
                    except Exception:
                        continue
                    t = ev.get("type")
                    if t == "user":
                        c = (ev.get("message") or {}).get("content")
                        if ev.get("isMeta"):
                            continue
                        if isinstance(c, str):
                            return rounds
                        if isinstance(c, list) and any(
                                isinstance(b, dict) and b.get("type") == "text" for b in c):
                            return rounds
                        continue  # tool_result carrier — same turn
                    if t == "assistant":
                        content = (ev.get("message") or {}).get("content") or []
                        if any(isinstance(b, dict) and b.get("type") == "tool_use"
                               and b.get("name") in AGENT_TOOLS for b in content):
                            rounds += 1
                if start == 0:
                    return rounds
                tail_bytes *= 4
    except Exception:
        return 0


def _iter_tool_uses(
    transcript_path: str, since: str | None = None
) -> Iterable[tuple[str, dict]]:
    """
    Yield (tool_name, tool_input) for every tool use in the transcript.

    Transcript event shape varies across Claude Code versions. We tolerate
    both legacy `{"type":"tool_use","name":...,"input":...}` blocks inside
    message.content and newer top-level `{"type":"tool_use","name":...}`
    entries.

    `since` — ISO-8601 UTC floor ("YYYY-MM-DDTHH:MM:SS"): events whose
    `timestamp` sorts before it are skipped. Events WITHOUT a timestamp are
    kept (fail-open — never make evidence vanish on a shape change).
    """
    for ev in _iter_transcript_events(transcript_path):
        if since and isinstance(ev, dict):
            ts = ev.get("timestamp")
            if isinstance(ts, str) and ts[:19] < since:
                continue
        # Top-level tool_use event.
        if isinstance(ev, dict) and ev.get("type") == "tool_use":
            yield (ev.get("name") or "", ev.get("input") or {})
            continue

        # Tool uses nested inside message.content blocks.
        msg = ev.get("message") if isinstance(ev, dict) else None
        if not isinstance(msg, dict):
            continue
        content = msg.get("content")
        if not isinstance(content, list):
            continue
        for block in content:
            if not isinstance(block, dict):
                continue
            if block.get("type") != "tool_use":
                continue
            yield (block.get("name") or "", block.get("input") or {})


def _load_risk_overrides():
    """Per-repo override: <git-root>/.rolepod/risk-paths — one ERE per line.
    Bare or `+`-prefixed lines ADD high-risk patterns; `-`-prefixed lines
    EXCLUDE paths from the built-in match; `#` starts a comment. Absent or
    unreadable file = built-ins only (fail-open)."""
    add, excl = [], []
    try:
        import subprocess
        root = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            text=True, stderr=subprocess.DEVNULL,
        ).strip()
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
    return add, excl


_RISK_ADD, _RISK_EXCL = _load_risk_overrides()


def is_high_risk_path(path: str) -> bool:
    if not path:
        return False
    hit = bool(HIGH_RISK_PATH.search(path)) or any(p.search(path) for p in _RISK_ADD)
    if hit and any(p.search(path) for p in _RISK_EXCL):
        return False
    return hit


def is_test_file(path: str) -> bool:
    if not path:
        return False
    return bool(TEST_FILE.search(path))


def is_code_file(path: str) -> bool:
    if not path:
        return False
    return bool(CODE_FILE.search(path))


def _file_from_input(tool_input: dict) -> str:
    return (
        tool_input.get("file_path")
        or tool_input.get("notebook_path")
        or ""
    )


def count_test_edits(transcript_path: str) -> int:
    n = 0
    for tool, inp in _iter_tool_uses(transcript_path):
        if tool not in EDIT_TOOLS:
            continue
        if is_test_file(_file_from_input(inp)):
            n += 1
    return n


def count_high_risk_edits(transcript_path: str) -> int:
    """
    Count PRODUCTION code edits on high-risk paths. Test files are excluded
    so writing `auth/login.test.ts` doesn't paradoxically trigger the same
    block it satisfies — those count toward count_test_edits instead.
    """
    n = 0
    for tool, inp in _iter_tool_uses(transcript_path):
        if tool not in EDIT_TOOLS:
            continue
        path = _file_from_input(inp)
        if is_test_file(path):
            continue
        if is_high_risk_path(path) and is_code_file(path):
            n += 1
    return n


def count_code_edits(transcript_path: str) -> int:
    n = 0
    for tool, inp in _iter_tool_uses(transcript_path):
        if tool not in EDIT_TOOLS:
            continue
        if is_code_file(_file_from_input(inp)):
            n += 1
    return n


def _bare_agent_name(subagent_type: str | None) -> str:
    """Strip a plugin namespace prefix — 'rolepod:qa-tester' -> 'qa-tester'.

    Plugin-installed agents are addressed as '<plugin>:<agent>'. A bare name
    with no colon is returned unchanged.
    """
    return (subagent_type or "").strip().rsplit(":", 1)[-1]


_WF_AGENTTYPE_RX = re.compile(r"agentType\s*:\s*['\"]([^'\"]+)['\"]")
_WF_MODEL_RX = re.compile(r"model\s*:\s*['\"]([^'\"]+)['\"]")


def _workflow_script(inp: dict) -> str:
    """The script of a Workflow tool call — inline, or read from scriptPath
    (re-invocations pass only the path). Missing/unreadable → ""."""
    script = inp.get("script") or ""
    if not script and inp.get("scriptPath"):
        try:
            with open(inp["scriptPath"]) as f:
                script = f.read()
        except OSError:
            script = ""
    return script


def count_workflow_reviewers(script: str) -> tuple[int, int]:
    """(reviewers, strong) among a Workflow script's agent() calls.

    Workflow fleets run reviewers as agent(..., {agentType:
    'rolepod:universal-reviewer'}) — that never appears as an Agent tool_use
    in any transcript, so without this the gate demanded a DUPLICATE
    Agent-tool reviewer after the workflow already reviewed. Strong mirrors
    the Agent-dispatch rule: an explicit known-low `model:` inside the same
    opts window is a downgrade, not the strong pass; no override (inherit)
    counts."""
    reviewers = strong = 0
    for m in _WF_AGENTTYPE_RX.finditer(script):
        name = _bare_agent_name(m.group(1))
        if name in REVIEWER_AGENTS:
            reviewers += 1
        if name in STRONG_REVIEWER_AGENTS:
            window = script[max(0, m.start() - 200):m.end() + 200]
            mm = _WF_MODEL_RX.search(window)
            if not (mm and model_class(mm.group(1)) in LOW_CLASSES):
                strong += 1
    return reviewers, strong


def count_reviewers_dispatched(transcript_path: str) -> int:
    """Times Lead spawned qa-tester / security-engineer / universal-reviewer.

    Matches the bare agent name and the plugin-namespaced form alike
    ('rolepod:qa-tester'), and both the 'Agent' and 'Task' subagent tools.
    A plugin-namespaced reviewer used to count as 0 — which false-blocked
    commits at the precommit gate even after review actually ran. Workflow
    scripts count via their agent() agentType calls (count_workflow_reviewers).
    """
    n = 0
    for tool, inp in _iter_tool_uses(transcript_path):
        if tool in AGENT_TOOLS:
            if _bare_agent_name(inp.get("subagent_type")) in REVIEWER_AGENTS:
                n += 1
        elif tool == "Workflow":
            n += count_workflow_reviewers(_workflow_script(inp))[0]
    return n


def _since_iso(since_epoch: float | None) -> str | None:
    if not since_epoch:
        return None
    try:
        import datetime
        return datetime.datetime.fromtimestamp(
            float(since_epoch), datetime.timezone.utc
        ).strftime("%Y-%m-%dT%H:%M:%S")
    except Exception:
        return None


# Newest-first cap on subagent transcripts scanned per gate call — a
# never-committed repo has no window, and a long session can hold hundreds
# of agent files (CourtBook: 293 / 127 MB). 60 newest covers any real fleet
# (Workflow concurrency caps at 16 per run).
AGENT_TRANSCRIPT_CAP = 60


def agent_transcripts(transcript_path: str, since_epoch: float | None = None) -> list[str]:
    """Subagent transcripts of the same session — Claude Code stores them
    next to the main file: `<session-id>/subagents/agent-*.jsonl` (Agent
    tool) and `<session-id>/subagents/workflows/<run>/agent-*.jsonl`
    (Workflow tool fleets). Walked recursively; only files modified at/after
    `since_epoch` (when given), newest first, capped. Delegated sessions put
    test-writing INSIDE subagents: without this the Lead's own transcript
    shows 0 test edits and the gate false-blocks — the documented reason
    users reach for ROLEPOD_GATES_SOFT."""
    if not transcript_path or not transcript_path.endswith(".jsonl"):
        return []
    sub = os.path.join(transcript_path[:-6], "subagents")
    if not os.path.isdir(sub):
        return []
    try:
        cands = []
        for root, _dirs, files in os.walk(sub):
            for fn in files:
                if not (fn.startswith("agent-") and fn.endswith(".jsonl")):
                    continue
                fp = os.path.join(root, fn)
                try:
                    mt = os.path.getmtime(fp)
                except OSError:
                    continue
                if since_epoch and mt < float(since_epoch):
                    continue
                cands.append((mt, fp))
        cands.sort(reverse=True)
        return [fp for _, fp in cands[:AGENT_TRANSCRIPT_CAP]]
    except Exception:
        return []


def count_all(
    transcript_path: str, since_epoch: float | None = None
) -> tuple[int, int, int, int]:
    """Single-pass tally of the four gate counts — one transcript scan instead
    of four. Returns (test_edits, high_risk_edits, reviewers, strong_reviewers);
    the first three identical to the standalone count_* they replace
    (test/high-risk are mutually exclusive per edit; test wins — same
    precedence as count_high_risk_edits' skip).

    v2.47.0 — evidence is WINDOWED to `since_epoch` (the gate passes the last
    commit's timestamp): a 12-day session must not clear today's commit with
    a reviewer dispatched ten days ago. Subagent transcripts of the same
    session (mtime inside the window) are tallied too — see agent_transcripts.
    A strong reviewer counts only when it was NOT explicitly dispatched at a
    known-low model (`model: sonnet` on universal-reviewer is a downgrade,
    not the strong pass); `inherit` counts because the dispatch hook lifts
    it to the strong alias on a low Lead."""
    since = _since_iso(since_epoch)
    test_edits = high_risk_edits = reviewers = strong_reviewers = 0
    paths = [transcript_path] + agent_transcripts(transcript_path, since_epoch)
    for tp in paths:
        for tool, inp in _iter_tool_uses(tp, since):
            if tool in EDIT_TOOLS:
                path = _file_from_input(inp)
                if is_test_file(path):
                    test_edits += 1
                elif is_high_risk_path(path) and is_code_file(path):
                    high_risk_edits += 1
            elif tool in AGENT_TOOLS:
                name = _bare_agent_name(inp.get("subagent_type"))
                if name in REVIEWER_AGENTS:
                    reviewers += 1
                if (name in STRONG_REVIEWER_AGENTS
                        and model_class(inp.get("model")) not in LOW_CLASSES):
                    strong_reviewers += 1
            elif tool == "Workflow":
                # Workflow-run reviewers (agent() agentType calls) count too —
                # a workflow that already reviewed must not force a duplicate
                # Agent-tool dispatch to clear the gate.
                r, s = count_workflow_reviewers(_workflow_script(inp))
                reviewers += r
                strong_reviewers += s
    return test_edits, high_risk_edits, reviewers, strong_reviewers


def count_parallel_agent_spawns_on_path(
    transcript_path: str, recent_window: int = 10
) -> int:
    """
    Count Agent spawns within the last `recent_window` tool uses that touch
    overlapping paths (heuristic — looks for path hints in the prompt). Used
    to detect parallel-agent fan-out that needs a cohesion contract.
    """
    recent: list[tuple[str, dict]] = []
    for tool, inp in _iter_tool_uses(transcript_path):
        recent.append((tool, inp))
        if len(recent) > recent_window:
            recent.pop(0)

    return sum(1 for tool, _ in recent if tool in AGENT_TOOLS)


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: session_state.py <query> [args]", file=sys.stderr)
        return 1

    query = sys.argv[1]

    if query == "is-high-risk-path":
        path = sys.argv[2] if len(sys.argv) > 2 else ""
        print("yes" if is_high_risk_path(path) else "no")
        return 0

    if query == "is-test-file":
        path = sys.argv[2] if len(sys.argv) > 2 else ""
        print("yes" if is_test_file(path) else "no")
        return 0

    hook_input = _load_hook_input()
    transcript_path = hook_input.get("transcript_path") or ""

    if query == "count-all":
        # test_edits high_risk_edits reviewers strong_reviewers — one line,
        # one transcript scan. Optional argv[2] = epoch floor (last commit).
        since_epoch = None
        if len(sys.argv) > 2 and sys.argv[2].strip():
            try:
                since_epoch = float(sys.argv[2])
            except ValueError:
                since_epoch = None
        print("%d %d %d %d" % count_all(transcript_path, since_epoch))
    elif query == "dispatch-rounds":
        # Assistant messages with an Agent/Task dispatch since the last user prompt.
        print(dispatch_rounds_this_turn(transcript_path))
    elif query == "context-tokens":
        # Context size (tokens) the last assistant turn carried — 0 unknown.
        print(last_context_tokens(transcript_path))
    elif query == "lead-class":
        # "<model> <class>" of the last assistant turn — "" unknown when
        # the transcript is missing or has no model field.
        m = lead_model(transcript_path)
        print("%s %s" % (m or "-", model_class(m)))
    elif query == "count-test-edits":
        print(count_test_edits(transcript_path))
    elif query == "count-high-risk-edits":
        print(count_high_risk_edits(transcript_path))
    elif query == "count-code-edits":
        print(count_code_edits(transcript_path))
    elif query == "count-reviewers-dispatched":
        print(count_reviewers_dispatched(transcript_path))
    elif query == "count-recent-agent-spawns":
        window = int(sys.argv[2]) if len(sys.argv) > 2 else 10
        print(count_parallel_agent_spawns_on_path(transcript_path, window))
    else:
        print(f"unknown query: {query}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
