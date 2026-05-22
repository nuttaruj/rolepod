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
    r"invoice|invoices)"
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

EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}

# Subagent-spawn tools. Claude Code has used both names across versions;
# match either so reviewer counting does not depend on the CLI version.
AGENT_TOOLS = {"Agent", "Task"}


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


def _iter_tool_uses(transcript_path: str) -> Iterable[tuple[str, dict]]:
    """
    Yield (tool_name, tool_input) for every tool use in the transcript.

    Transcript event shape varies across Claude Code versions. We tolerate
    both legacy `{"type":"tool_use","name":...,"input":...}` blocks inside
    message.content and newer top-level `{"type":"tool_use","name":...}`
    entries.
    """
    for ev in _iter_transcript_events(transcript_path):
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


def is_high_risk_path(path: str) -> bool:
    if not path:
        return False
    return bool(HIGH_RISK_PATH.search(path))


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


def count_reviewers_dispatched(transcript_path: str) -> int:
    """Times Lead spawned qa-tester / security-engineer / universal-reviewer.

    Matches the bare agent name and the plugin-namespaced form alike
    ('rolepod:qa-tester'), and both the 'Agent' and 'Task' subagent tools.
    A plugin-namespaced reviewer used to count as 0 — which false-blocked
    commits at the precommit gate even after review actually ran.
    """
    n = 0
    for tool, inp in _iter_tool_uses(transcript_path):
        if tool not in AGENT_TOOLS:
            continue
        if _bare_agent_name(inp.get("subagent_type")) in REVIEWER_AGENTS:
            n += 1
    return n


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

    if query == "count-test-edits":
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
