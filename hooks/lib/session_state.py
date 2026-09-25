#!/usr/bin/env python3
"""
Session-state inspector for rolepod hooks.

Claude Code passes `transcript_path` in every hook input. The transcript is
a JSONL log of every assistant message + tool use in the current session.
This script parses it to answer questions hooks need to enforce gates:

  - How many test files has Lead edited this session?
  - How many high-risk code files (auth/billing/etc.) has Lead edited?
  - Has Lead dispatched security-engineer / universal-reviewer (the review floor)?

CLI: pass a hook-input JSON on stdin, request a query as argv[1]. Output is
plain stdout (a number or one space-separated line), exit 0 on success,
non-zero on parse error.

Designed to be cheap (single scan of transcript) and safe (graceful fallback
to 0 / empty when transcript path missing or unreadable — hooks must not
block on infrastructure failure).
"""
from __future__ import annotations

import json
import os
import re
import shlex
import sys
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
    # Every filename alternative below is case-SENSITIVE AS A WHOLE (one
    # local `(?-i:...)` group; the pattern is compiled with re.IGNORECASE
    # for the directory alternative above only): the commit gate's own
    # filename filter (precommit-gate.sh HIGH_RISK= line) has no -i, so a
    # lowercase-`test` collision inside an unrelated word (AppAttest.swift,
    # Latest.java, Contest.cs) must not be exempted here while the gate
    # still calls it high-risk, and `invoice.TEST.py` must not be exempted
    # here while the gate still calls IT high-risk either — reviewed
    # 2026-09-24, breaker round 2.
    r"(?-i:\.(test|spec)\.(ts|tsx|js|jsx|mjs|cjs|py|go|rs|rb|java|kt|swift|cs|php)$"
    r"|(^|/)(test_[^/]*|[^/]*_test|[^/]*_spec)\.(py|go|rs|rb|php)$"
    r"|(^|/)[^/]*Tests?\.(java|kt|cs|swift|php|scala)$)",
    re.IGNORECASE,
)

# Source-code file extensions (used to count "code edits" vs docs/configs).
CODE_FILE = re.compile(
    r"\.(ts|tsx|js|jsx|py|go|rs|rb|java|kt|swift|cs|cpp|c|h|hpp|php|lua|sh|bash)$",
    re.IGNORECASE,
)

REVIEWER_AGENTS = {
    "security-engineer",
    "universal-reviewer",
    "code-reviewer",
}

# Strong-class adversarial reviewers — the subset whose dispatch clears a
# HIGH-RISK commit gate. qa-tester is user-visible verification (E2E) and
# never the per-diff review floor (v2.148.4): its dispatch counts at neither
# gate.
STRONG_REVIEWER_AGENTS = {
    "security-engineer",
    "universal-reviewer",
    "code-reviewer",
}

EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}

# Subagent-spawn tools. Claude Code has used both names across versions;
# match either so reviewer counting does not depend on the CLI version.
AGENT_TOOLS = {"Agent", "Task"}

# ── Shell-command tokenizer ────────────────────────────────────────────
# Shared by block-subagent-commit.sh's commit-ban and cannot-wait rules:
# both need to walk a shell command the same way (split into segments, drop
# heredoc bodies, skip past a wrapper word's flags/values, recurse into a
# shell's -c string) — a second hand-written copy of the wrapper/value-flag
# tables would drift. This is the ONLY copy; block-subagent-commit.sh
# imports these names instead of defining them locally.
PREFIX = {'time', 'env', 'nice', 'sudo', 'rtk', 'proxy', 'caffeinate', 'command', 'exec', 'nohup', 'timeout'}
# per wrapper: the flags that take the NEXT token as their value (sudo -n / -k / -s are booleans)
WRAPPER_VALUE = {'sudo': {'-u', '-g', '-C', '-p', '-h', '-r', '-t', '-U', '-D'}, 'nice': {'-n'},
                 'env': {'-u', '-C', '-S'}, 'timeout': {'-k', '-s'}, 'nohup': set(), 'caffeinate': {'-t', '-w'}}
DURATION = re.compile(r'^[0-9]+(\.[0-9]+)?[smhd]?$')          # 300 / 5m / 1.5h after timeout / nice -n
SHELLS = {'bash', 'sh', 'zsh', 'dash', 'ksh'}
ASSIGN = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*=')
OUTPUT_ONLY = {'echo', 'printf', ':'}
# no quote characters on this line: bash 3.2 counts quotes inside $( <<heredoc ) while looking for the closing paren
HEREDOC = re.compile(r'<<-?\s*([^\s\w]?)(\w+)\1[^\n]*\n(.*?)\n\s*\2(?=\n|$)', re.S)


def toks_of(s):
    try:
        return shlex.split(s)
    except ValueError:
        return s.split()


def owner_is_shell(text, start):
    # the line that opens a heredoc, marker removed: the body is a program when
    # any command on that line (bash <<EOF, cat <<EOF | sh) is a shell
    ls = text.rfind('\n', 0, start) + 1
    le = text.find('\n', start)
    line = text[ls:(le if le >= 0 else len(text))]
    line = re.sub(r'<<-?\s*[^\s\w]?\w+[^\s\w]?', ' ', line, count=1)
    for part in re.split(r'\s*(?:\||&&|;)\s*', line):
        if any(os.path.basename(x) in SHELLS for x in head(toks_of(part))):
            return True
    return False


def segments(text):
    # a heredoc body is data (cat / tee / a redirect) and is dropped before
    # splitting - unless a shell owns it: then the body IS the program, the
    # same way a -c string is, and its lines stay in as segments
    def sub(m):
        return '\n' + m.group(3) + '\n' if owner_is_shell(text, m.start()) else '<<HEREDOC'
    text = HEREDOC.sub(sub, text)
    return re.split(r'\s*(?:&&|\|\||;|\||\n)\s*', text)


def head(t):
    w = ''
    while t:
        if t[0] in PREFIX:
            w = t[0]; t = t[1:]
        elif t[0].startswith('-'):
            t = t[2:] if (t[0] in WRAPPER_VALUE.get(w, set()) and len(t) > 1) else t[1:]
        elif DURATION.match(t[0]) or ASSIGN.match(t[0]):
            t = t[1:]
        else:
            break
    return t


_ROOT_CACHE: dict = {}


def _git_root(cwd):
    """git rev-parse --show-toplevel from `cwd`, cached per cwd (a counting
    pass calls this once per tool_use — the cache keeps it to one shell-out
    per distinct cwd). "" when not a repo / git missing (fail-open)."""
    key = cwd or ''
    if key in _ROOT_CACHE:
        return _ROOT_CACHE[key]
    root = ''
    try:
        import subprocess
        root = subprocess.run(
            ['git', 'rev-parse', '--show-toplevel'], cwd=cwd or None,
            capture_output=True, text=True, timeout=10,
        ).stdout.strip()
    except Exception:
        root = ''
    _ROOT_CACHE[key] = root
    return root


def _repo_relative(root, path):
    """Repo-relative when `path` sits under `root` — compared on realpaths,
    so a CLI's own absolute spelling (/var/... vs git's /private/var/...) resolves the same
    way in every copy. Every classification call (is_test_file /
    is_high_risk_path / is_code_file) goes through this first: a raw
    absolute path defeats a root-anchored `.rolepod/risk-paths` line
    (`^design_tokens/`) and can make an ancestor directory named `auth`
    outside the repo look risky — reviewed 2026-09-24, breaker round 2."""
    if not path or not root:
        return path
    try:
        rr, rp = os.path.realpath(root), os.path.realpath(path)
        if rp.startswith(rr + os.sep):
            return rp[len(rr) + 1:]
    except Exception:
        pass
    if path.startswith(root + "/"):
        return path[len(root) + 1:]
    return path


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

# Strong-tier roles render `model: opus` on Claude since v2.104.0 — their own
# frontmatter pin, not a hook-side lift (that rewrite is gone, hook-layer-lean
# 2026-09-25). opus is the paid CEILING of the strong tier by owner decision:
# a fable-class Lead keeps its own model but its strong reviewers run opus —
# never lifted (cost). system-architect joined in v2.73.0: it writes the spec
# + cohesion contract for parallel work — the judgment-heaviest role — and
# was the one strong role left at nudge-only.
STRONG_ROLE_AGENTS = {"security-engineer", "universal-reviewer", "system-architect"}

# Roles whose rendered Claude frontmatter carries a REAL `model:` pin
# (merge-agent.py TIER_MODELS: cheap -> haiku, balanced -> sonnet). A Workflow
# `agentType:` of one of these IS a tier choice; a platform agent
# (general-purpose / Explore / claude / Plan) or another plugin's agent renders
# no pin and silently inherits the Lead. tests/static/hook-agent-matching.sh
# asserts this set against the tier overlays, so a new role cannot drift out.
TIER_PINNED_AGENTS = {
    "content-strategist", "scout",                               # cheap
    "ai-ml-engineer", "backend-developer", "billing-engineer",   # balanced
    "data-scientist", "devops-sre", "frontend-developer",
    "mobile-developer", "performance-engineer", "qa-tester",
    "ui-ux-designer",
}

# Roles that OWN product code in the plan-template domain map (write-plan
# "Owners and briefs", v2.115.0). Reviewer / test-only / read-only roles are not
# owners; scout and system-architect are read-only at the moment of dispatch.
WRITER_ROLE_AGENTS = {
    "ai-ml-engineer", "backend-developer", "billing-engineer",
    "content-strategist", "data-scientist", "devops-sre",
    "frontend-developer", "mobile-developer", "performance-engineer",
    "ui-ux-designer",
}

# Product code for the self-do nudge: a CODE_FILE that is not a test by
# TEST_FILE and not under a test / mock / fixture / docs / build tree, and
# not a pytest module or config. One regex, used both to decide whether the
# edited target starts the scan AND to count earlier edits — the two must
# agree or historical test edits inflate the count.
_SELFDO_SKIP = re.compile(
    r"(^|/)(docs?|\.github|\.rolepod|node_modules|dist|build|"
    r"tests?|__tests__|__mocks__|__snapshots__|spec|specs|e2e|fixtures?|"
    r"cypress|playwright|testdata)/|"
    r"\.(test|spec|test-d|cy)\.[A-Za-z0-9]+$|"
    r"(^|/)(test_[^/]+\.py|conftest\.py)$",
    re.IGNORECASE,
)


# Infra files are product code for the nudge too — the same paths the
# plan-template Owner map assigns to devops-sre (no CODE_FILE extension, and
# .github/ sits in the skip list, so they need their own positive rule).
# Applied to the path RELATIVE to the repo root (is_product_code relativizes
# with `root`): the directory rule is root-anchored so docs/deploy/guide.md
# or src/deploy/handler.ts never read as infra, and nested layouts
# (terraform/modules/vpc/main.tf, k8s/overlays/prod/x.yaml) do; a .md inside
# an infra dir stays a doc. Dockerfile / compose match at any depth
# (monorepo services carry their own).
_INFRA_PATH = re.compile(
    r"^(\.github/workflows/[^/]+\.ya?ml|\.gitlab-ci\.yml|\.circleci/.+|"
    r"vercel\.json|wrangler\.(toml|jsonc?)|fly\.toml|railway\.(json|toml)|"
    r"netlify\.toml|render\.yaml|Procfile|scripts/(deploy|release)[^/]*|"
    r"(deploy|infra|terraform|k8s|helm)/(?!.*\.md$).+)$"
    r"|(^|/)(Dockerfile[^/]*|docker-compose[^/]*\.ya?ml|compose\.ya?ml)$",
    re.IGNORECASE,
)


def is_product_code(path: str, root: str | None = None) -> bool:
    """Product code for the self-do nudge. With `root` (the git worktree),
    a path outside it is never product code and the infra rule sees the
    root-relative path; without it the absolute path is judged as-is."""
    if not path:
        return False
    if root:
        # realpath both sides: the hook hands the git root as a realpath
        # (/private/var/...), the transcript holds the path as the model
        # typed it (/var/... on macOS) — a symlinked prefix must still match.
        r = os.path.realpath(root).rstrip("/") + "/"
        ap = os.path.realpath(path) if os.path.isabs(path) else path
        if ap.startswith(r):
            path = ap[len(r):]
        elif os.path.isabs(path):
            return False
    if _INFRA_PATH.search(path):
        return True
    return is_code_file(path) and not is_test_file(path) \
        and not _SELFDO_SKIP.search(path)


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


def _iter_events_reversed(transcript_path: str, chunk_bytes: int = 1 << 20) -> Iterable[dict]:
    """Newest-first JSONL events, read from the END in chunks. A scan that
    stops at a recent boundary (the newest routing line, the last commit's
    timestamp) then pays for the span it needs, not the whole file —
    measured 2026-09-14: selfdo_state 596 ms and count_all 732 ms per edit
    on a 261 MB transcript when both read front to back. Unparsable lines
    are skipped; a missing file yields nothing."""
    if not transcript_path or not os.path.isfile(transcript_path):
        return
    try:
        with open(transcript_path, "rb") as f:
            f.seek(0, os.SEEK_END)
            pos = f.tell()
            carry = b""
            while pos > 0:
                step = min(chunk_bytes, pos)
                pos -= step
                f.seek(pos)
                lines = (f.read(step) + carry).split(b"\n")
                carry = lines[0]   # a partial first line belongs to the chunk before it
                for raw in reversed(lines[1:]):
                    raw = raw.strip()
                    if not raw:
                        continue
                    try:
                        yield json.loads(raw)
                    except Exception:
                        continue
            raw = carry.strip()
            if raw:
                try:
                    yield json.loads(raw)
                except Exception:
                    pass
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
    if since:
        # Windowed → newest-first from the file's end; the transcript is
        # append-only and chronological, so 50 consecutive events older than
        # the floor mean the floor is behind us and the scan stops there.
        # Timestamp-less events are still yielded and never count as stale.
        stale = 0
        for ev in _iter_events_reversed(transcript_path):
            if not isinstance(ev, dict):
                continue
            ts = ev.get("timestamp")
            if isinstance(ts, str) and ts[:19] < since:
                stale += 1
                if stale >= 50:
                    break
                continue
            stale = 0
            yield from _tool_uses_of(ev)
        return
    for ev in _iter_transcript_events(transcript_path):
        yield from _tool_uses_of(ev)


def _tool_uses_of(ev) -> Iterable[tuple[str, dict]]:
    # Top-level tool_use event.
    if isinstance(ev, dict) and ev.get("type") == "tool_use":
        yield (ev.get("name") or "", ev.get("input") or {})
        return
    # Tool uses nested inside message.content blocks.
    msg = ev.get("message") if isinstance(ev, dict) else None
    if not isinstance(msg, dict):
        return
    content = msg.get("content")
    if not isinstance(content, list):
        return
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


def count_test_edits(transcript_path: str, cwd: str | None = None) -> int:
    n = 0
    for tool, inp in _iter_tool_uses(transcript_path):
        if tool in EDIT_TOOLS:
            root = _git_root(cwd or "")
            if is_test_file(_repo_relative(root, _file_from_input(inp))):
                n += 1
    return n


def _bare_agent_name(subagent_type: str | None) -> str:
    """Strip a plugin namespace prefix — 'rolepod:qa-tester' -> 'qa-tester'.

    Plugin-installed agents are addressed as '<plugin>:<agent>'. A bare name
    with no colon is returned unchanged.
    """
    return (subagent_type or "").strip().rsplit(":", 1)[-1]


# Workflow scripts: agent() OPTIONS are code, prompts are string literals. A key
# read off the raw script also matches prose — a prompt saying "give each sweep
# agentType: 'rolepod:scout'" registered as a real tier choice and silenced the
# fleet-tier gate (the `model:` half of this was v2.62.1, the `agentType:` half
# v2.88.0). strip_strings() blanks literal CONTENTS but keeps LENGTH and quotes,
# so a key found in the stripped text reads its value from the original at the
# same offset.
# v2.124.0: line + block comments are neutralized in the SAME pass, and BEFORE
# the string rules. A `//` comment written in English prose carries apostrophes
# ("the Lead's tier", "don't", "it's") — with no comment rule the stripper read
# that `'` as opening a string literal, flipped quote parity for the rest of the
# script, and blanked every agent() call after it. The per-call loop then found
# zero calls, so strong-spread / reason-spread / bare-fanout never fired
# (observed: CourtBook coach-daily-wage, a `// tier-reason:` mentioning "Lead's
# tier" silenced an 8×opus fleet). A `//` inside a string is still consumed as
# string content, because the opening quote matches first at its own position.
# A `/` opens a JS regex LITERAL (not division) only when the last
# significant token before it is start-of-script, one of these punctuation
# marks, or one of the prefix keywords below — the usual disambiguation
# heuristic. Not exhaustive (a real JS parser tracks full expression state);
# good enough to keep a division `a / b` as code while still recognizing the
# regex literals a Workflow script actually writes.
_SCRIPT_STR_RX = re.compile(
    r"//[^\n]*"                 # line comment
    r"|/\*.*?\*/"               # block comment
    r"|`(?:\\.|[^`\\])*`"       # template literal
    r"|'(?:\\.|[^'\\])*'"       # single-quoted
    r'|"(?:\\.|[^"\\])*"',      # double-quoted
    re.S)


def _blank_token(m: "re.Match") -> str:
    s = m.group(0)
    if s[:2] in ("//", "/*"):
        # a comment carries no tier choice — blank it whole (newlines kept so
        # every later offset and line count is unchanged)
        return "".join("\n" if c == "\n" else " " for c in s)
    # string literal: keep the quote marks, blank the contents (newline-safe)
    return s[0] + "".join("\n" if c == "\n" else " " for c in s[1:-1]) + s[-1]


def strip_strings(script: str) -> str:
    """Blank string literals and comments, preserving length, newlines, and
    the string quote marks — so a `key:` found in the result reads its value
    from the original script at the same offset.

    Reverted to this shape 2026-09-24 (spec 6b): a regex-literal-aware
    version briefly existed to close a specific desync (c75a324c), but a
    second review round found more shapes it still mis-tokenized (`if (x)
    /'/g`, `{} / 'x / y'`, a CRLF line continuation). The lesson (two rounds,
    two new escapes each time): a script-text lexer guarding a security
    surface can always be fooled by a crafted shape — a Workflow reviewer is
    no longer counted from script text at all (see `count_all`'s Workflow
    handling, which now reads `agent-<id>.meta.json` run evidence instead).
    This function still guards the tier/model-spread nudges
    (workflow-tier-nudge.sh) and the dispatch-auto-log stats line, where a
    misread only skews advisory numbers, not a commit-gate decision — no
    security path depends on it now."""
    return _SCRIPT_STR_RX.sub(_blank_token, script or "")


def script_option_values(script: str, key: str, code: str | None = None) -> list[str]:
    """Literal values of `<key>:` written as CODE, in source order.

    A value inside a prompt / template string is NOT a tier choice and is
    skipped. Pass `code` when the caller already stripped the same script.
    """
    script = script or ""
    if code is None:
        code = strip_strings(script)
    out = []
    for m in re.finditer(r"[,{\s]" + re.escape(key) + r"\s*:\s*['\"]", code):
        q = m.end() - 1
        mv = re.match(r"['\"]([^'\"]+)['\"]", script[q:q + 200])
        if mv:
            out.append(mv.group(1))
    return out


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


_WRITE_MODE_RE = re.compile(r"\bwrite[- ]mode\b", re.IGNORECASE)
_REVIEW_MODE_RE = re.compile(r"\breview[- ]mode\b", re.IGNORECASE)


def is_write_mode_brief(prompt) -> bool:
    """True when a dispatch brief declares write-mode (the qa-tester mode
    contract). Such a dispatch authors tests; it is never the review.
    A brief that also says review-mode ("review-mode, not write-mode" — the
    agent file's own vocabulary) is a review: fail-open toward counting."""
    return bool(isinstance(prompt, str) and _WRITE_MODE_RE.search(prompt)
                and not _REVIEW_MODE_RE.search(prompt))


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


def _workflow_meta_reviewer(meta_path: str, since_epoch: float | None = None) -> tuple[int, int]:
    """(reviewer, strong) for ONE Workflow sub-agent, read from its
    `agent-<id>.meta.json` — Claude Code writes it beside the sub-agent's own
    transcript, under `subagents/workflows/<run>/` (`{"agentType": "...",
    "model": "...", ...}`). Never from the Workflow tool_use's script text:
    a script-level lexer guarding this same decision was tried twice
    (c75a324c, 417c7f9e) and beaten twice, by a `/'/g`-shaped regex literal
    and then by an `if (x) /'/g`-shaped one and a CRLF line continuation —
    two rounds proved a script-text lexer on a security surface can always
    be fooled by one more crafted shape (spec 6b, S12). Missing / unreadable
    / malformed meta → (0, 0), fail-closed — a reviewer this file cannot
    positively identify does not count. `since_epoch`, when given, is also
    checked against the META FILE'S OWN mtime, never just its paired
    `.jsonl`'s: the caller (`count_all`) already windowed the jsonl through
    `agent_transcripts()`, but a `.meta.json` `touch`ed after the fact (to
    resurrect an old Workflow reviewer into a NEW commit's window) has a
    fresher jsonl mtime and a stale meta mtime — checking only the jsonl
    let that forged evidence back in (security review 2026-09-24, MINOR-5,
    external cross-family pass)."""
    try:
        if since_epoch and os.path.getmtime(meta_path) < float(since_epoch):
            return 0, 0
    except OSError:
        return 0, 0
    try:
        with open(meta_path) as f:
            meta = json.load(f)
    except Exception:
        return 0, 0
    if not isinstance(meta, dict):
        return 0, 0
    name = _bare_agent_name(meta.get("agentType"))
    reviewer = 1 if name in REVIEWER_AGENTS else 0
    strong = 1 if (name in STRONG_REVIEWER_AGENTS
                   and model_class(meta.get("model")) not in LOW_CLASSES) else 0
    return reviewer, strong


def count_all(
    transcript_path: str, since_epoch: float | None = None, cwd: str | None = None
) -> tuple[int, int, int, int]:
    """Single-pass tally of the four gate counts — one transcript scan instead
    of four. Returns (test_edits, high_risk_edits, reviewers, strong_reviewers);
    test / high-risk are mutually exclusive per edit: a test-file edit counts
    as a test edit, never as a high-risk edit.

    v2.47.0 — evidence is WINDOWED to `since_epoch` (the gate passes the last
    commit's timestamp): a 12-day session must not clear today's commit with
    a reviewer dispatched ten days ago. Subagent transcripts of the same
    session (mtime inside the window) are tallied too — see agent_transcripts.
    A strong reviewer counts only when it was NOT explicitly dispatched at a
    known-low model (`model: sonnet` on universal-reviewer is a downgrade,
    not the strong pass); a model-less Agent/Task dispatch counts strong
    because the role renders `model: opus` (v2.104.0).

    A Workflow tool_use itself is never scanned for reviewers (spec 6b,
    2026-09-24): only its SPAWNED sub-agent transcripts, discovered by
    `agent_transcripts()` under `subagents/workflows/<run>/`, each read from
    its own `agent-<id>.meta.json` run evidence — see
    `_workflow_meta_reviewer`. An Agent/Task dispatch keeps the transcript
    rule above (write-mode included); its own subagent file sits directly
    under `subagents/`, never under `subagents/workflows/`, so it is never
    double-counted through this path."""
    since = _since_iso(since_epoch)
    test_edits = high_risk_edits = reviewers = strong_reviewers = 0
    subs = agent_transcripts(transcript_path, since_epoch)
    paths = [transcript_path] + subs
    for tp in paths:
        for tool, inp in _iter_tool_uses(tp, since):
            if tool in EDIT_TOOLS:
                root = _git_root(cwd or "")
                path = _repo_relative(root, _file_from_input(inp))
                if is_test_file(path):
                    test_edits += 1
                elif is_high_risk_path(path) and is_code_file(path):
                    high_risk_edits += 1
            elif tool in AGENT_TOOLS:
                name = _bare_agent_name(inp.get("subagent_type"))
                # A brief that declares write-mode is a writer, not a
                # reviewer (v2.113.0 rule, folded into count_all so it no
                # longer needs a separate caller — F1): it counts toward
                # neither reviewers nor strong_reviewers.
                if is_write_mode_brief(inp.get("prompt")):
                    continue
                if name in REVIEWER_AGENTS:
                    reviewers += 1
                if (name in STRONG_REVIEWER_AGENTS
                        and model_class(inp.get("model")) not in LOW_CLASSES):
                    strong_reviewers += 1
    for tp in subs:
        if not tp.endswith(".jsonl"):
            continue
        parts = tp.split(os.sep)
        if "subagents" in parts and "workflows" in parts:
            r, s = _workflow_meta_reviewer(tp[:-len(".jsonl")] + ".meta.json", since_epoch)
            reviewers += r
            strong_reviewers += s
    return test_edits, high_risk_edits, reviewers, strong_reviewers


def _phase_log_reviewer_counts(phase, since_epoch, path, provenance="", strict=False):
    """(reviewers, strong) tally from phase-log.jsonl rows of one `phase`
    value. `provenance` "" = no requirement; the one caller in this file
    (the hook-auto dispatch backstop) passes `"hook-auto"`. `strict`
    additionally drops a STRONG row whose model is a named low-class
    downgrade (the hook-auto backstop only)."""
    r = s = 0
    cut = None
    if since_epoch:
        import datetime
        try:
            cut = datetime.datetime.fromtimestamp(float(since_epoch), datetime.timezone.utc)
        except Exception:
            cut = None
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                try:
                    d = json.loads(line)
                    if not isinstance(d, dict) or d.get("phase") != phase:
                        continue
                    if provenance and d.get("provenance") != provenance:
                        continue
                    if d.get("write_mode"):
                        continue
                    if cut is not None:
                        import datetime
                        ts_raw = d.get("ts") or ""
                        if not isinstance(ts_raw, str):
                            continue
                        ts = datetime.datetime.fromisoformat(ts_raw.replace("Z", "+00:00"))
                        # A naive ts (no offset) is dropped, not assumed UTC —
                        # a hand-written row without a timezone must never
                        # buy reviewer credit across a commit boundary.
                        if ts.tzinfo is None or ts < cut:
                            continue
                    name = _bare_agent_name(d.get("agent_type"))
                    if name.startswith("rolepod-"):
                        # Codex/Cursor/Antigravity dispatch rows may carry
                        # the plugin-prefixed bare name (no ':').
                        name = name[len("rolepod-"):]
                    # Both flags resolved BEFORE either counter moves
                    # (round-2 review MINOR-1): model_class() raising on a
                    # malformed `model` must not leave `r` incremented with
                    # `s` never reached — the whole row is all-or-nothing.
                    is_reviewer = name in REVIEWER_AGENTS
                    is_strong = name in STRONG_REVIEWER_AGENTS and (
                        not strict or model_class(d.get("model")) not in LOW_CLASSES)
                    if is_reviewer:
                        r += 1
                    if is_strong:
                        s += 1
                except Exception:
                    # One malformed row (a non-string agent_type/model/ts)
                    # must never zero every OTHER row in the window.
                    continue
    except OSError:
        pass
    return r, s


def _anchored_external_count(since_epoch, ev_dir):
    """Anchored cross-family review passes since `since_epoch` — a phase-log
    `review` row with `reviewer: external` whose raw output sits under
    `ev_dir`, is relative, has no `..`, and is >= 500 bytes. precommit-gate.sh
    reads this XREV count from gate_evidence() below, not its own inline
    computation (that bash copy is gone; satellite-first, v2.61.0)."""
    import datetime
    cut = None
    if since_epoch:
        try:
            cut = datetime.datetime.fromtimestamp(float(since_epoch), datetime.timezone.utc)
        except Exception:
            cut = None
    n = 0
    try:
        with open(os.path.join(ev_dir, "phase-log.jsonl"), encoding="utf-8", errors="replace") as f:
            for line in f:
                try:
                    d = json.loads(line)
                    if not isinstance(d, dict) or d.get("phase") != "review" or d.get("reviewer") != "external":
                        continue
                    if cut is not None:
                        ts = datetime.datetime.fromisoformat((d.get("ts") or "").replace("Z", "+00:00"))
                        if ts.tzinfo is None:
                            ts = ts.replace(tzinfo=datetime.timezone.utc)
                        if ts < cut:
                            continue
                    raw = d.get("raw") or ""
                    if not isinstance(raw, str) or not raw or raw.startswith("/") or ".." in raw:
                        continue
                    # P1 (Lead close-out, round 2 residual): `raw` must sit
                    # under evidence/external/ — the anchor point review-code
                    # actually writes to. Before this, `"raw":
                    # "phase-log.jsonl"` (or another evidence file, or a
                    # symlink placed under external/) passed the relative/no-".."/>=500B
                    # checks and counted as a real cross-family pass — the
                    # cheapest forgery in the gate. Both the name prefix and
                    # the resolved realpath are checked (a symlink under
                    # external/ pointing elsewhere must not count either).
                    if not raw.startswith("external/"):
                        continue
                    candidate = os.path.join(ev_dir, raw)
                    ext_root = os.path.realpath(os.path.join(ev_dir, "external"))
                    real = os.path.realpath(candidate)
                    if real != ext_root and not real.startswith(ext_root + os.sep):
                        continue
                    if os.path.getsize(candidate) >= 500:
                        n += 1
                except Exception:
                    # One malformed row (a non-string raw/ts, a NUL byte in
                    # the path) must never zero every OTHER anchored pass in
                    # the window — same defense as _phase_log_reviewer_counts.
                    continue
    except OSError:
        pass
    return n


def _window_since_epoch(diff_dir):
    """Since-epoch at `diff_dir` — `git log -1 --format=%ct`, or (a linked
    worktree, v2.153.0) the newest HEAD reflog line whose subject starts
    with "commit", else the oldest line (the worktree's creation). Python
    twin of precommit-gate.sh's SINCE_EPOCH block — S11 pins the two
    windows equal on the same fixture. None when the directory has no
    commits yet (whole-session evidence)."""
    import subprocess

    def run(*args):
        try:
            return subprocess.run(
                ["git", "-C", diff_dir, *args], capture_output=True, text=True, timeout=10
            ).stdout.strip()
        except Exception:
            return ""

    since_epoch = None
    ct = run("log", "-1", "--format=%ct")
    if ct:
        try:
            since_epoch = float(ct)
        except ValueError:
            since_epoch = None
    # Resolved to an absolute, symlink-resolved path before comparing
    # (MEDIUM-3, round-1 review): from a subdirectory of the MAIN worktree,
    # git prints an absolute --git-dir but a RELATIVE --git-common-dir — the
    # raw strings then always differ and a plain-repo subdir call wrongly
    # took the linked-worktree reflog branch. Kept in parity with the same
    # fix in precommit-gate.sh's bash block.
    def abspath(raw):
        if not raw:
            return ""
        try:
            return os.path.realpath(raw if os.path.isabs(raw) else os.path.join(diff_dir, raw))
        except Exception:
            return ""

    git_dir = abspath(run("rev-parse", "--git-dir"))
    git_cdir = abspath(run("rev-parse", "--git-common-dir"))
    if git_dir and git_cdir and git_dir != git_cdir:
        rlog = run("reflog", "show", "--date=unix", "--format=%gd %gs", "HEAD")
        if rlog:
            lines = rlog.splitlines()
            pick = None
            for ln in lines:
                if re.match(r"^HEAD@\{[0-9]+\}\s+commit", ln):
                    pick = ln
                    break
            if pick is None and lines:
                pick = lines[-1]
            if pick:
                m = re.match(r"^HEAD@\{([0-9]+)\}", pick)
                if m:
                    since_epoch = float(m.group(1))
    return since_epoch


def _evidence_root(diff_dir):
    """Config / evidence root (v2.153.0, R3): the hook's own process cwd's
    git root — every writer hook (phase-log, bypass.log, session locks)
    puts its state there — falling back to `diff_dir`'s
    toplevel only when the process cwd is not itself a git work tree."""
    import subprocess

    def toplevel(cwd):
        try:
            return subprocess.run(
                ["git", "-C", cwd, "rev-parse", "--show-toplevel"],
                capture_output=True, text=True, timeout=10,
            ).stdout.strip()
        except Exception:
            return ""

    root = toplevel(".")
    if not root:
        root = toplevel(diff_dir)
    return root


def _evidence_dirs(diff_dir):
    """The evidence roots for `diff_dir` (2026-09-25, D6, same fix reused by
    `gate_evidence` and `gate_hold_predict`): `_evidence_root(diff_dir)`
    (the session cwd's git root) AND `diff_dir`'s own toplevel
    (`_git_root`), deduplicated by realpath to one when they coincide (the
    ordinary non-worktree case — every writer hook already puts its state
    there, so this stays a no-op there). A commit made from a session's own
    checkout into a linked worktree (`cd <wt> && git commit`, `git -C <wt>
    commit`) otherwise loses every anchored external pass AND every
    external-fail row a cross-family run wrote to the WORKTREE's own
    `.rolepod/evidence/` — reading only the session root missed both.
    "" entries (no git root either way) dropped."""
    roots = []
    seen = set()
    for r in (_evidence_root(diff_dir), _git_root(diff_dir)):
        if not r:
            continue
        real = os.path.realpath(r)
        if real in seen:
            continue
        seen.add(real)
        roots.append(r)
    return roots


def gate_evidence(hook_input: dict, diff_dir: str) -> tuple[int, int, int, int, int]:
    """One evidence tally for both the commit gate and the edit-time
    reminder (spec Desired 10, 2026-09-25): the window computed once at
    `diff_dir` (the commit's resolved directory for the gate, the edited
    file's directory for the reminder) — returns (test_edits,
    high_risk_edits, reviewers, strong_reviewers, external). MAX per
    source, never summed: the transcript scan (count_all) and the
    hook-auto phase-log "dispatch" backstop (nested Agent dispatches the
    transcript walk's cap dropped). Claude-native only: no cross-CLI
    provenance rows, no bash-write scope tracker — this function runs
    only on Claude (precommit-gate.sh's ROLEPOD_LEAD_CLI check excludes
    every other CLI before calling it). Anchored external passes (XREV)
    ADD on top of reviewers / strong_reviewers, same as the gate's own
    long-standing rule, and are also returned on their own for the
    satellite-first hold.

    Evidence is read from every `_evidence_dirs(diff_dir)` root (D6,
    2026-09-25), not `_evidence_root(diff_dir)` alone. Per dir: the
    hook-auto dispatch counts still combine by MAX (the existing rule,
    now also across dirs — never summed), the anchored external count by
    SUM (distinct files in distinct dirs; every existing forgery check in
    `_anchored_external_count` — raw under that dir's own `external/`,
    realpath inside it, >= 500 B — holds per dir). The window stays one
    `_window_since_epoch(diff_dir)` call for every dir."""
    diff_dir = diff_dir or "."
    transcript_path = hook_input.get("transcript_path") or ""
    since_epoch = _window_since_epoch(diff_dir)

    test_edits, high_risk_edits, reviewers, strong = count_all(
        transcript_path, since_epoch, hook_input.get("cwd"))

    external = 0
    for root in _evidence_dirs(diff_dir):
        ev_dir = os.path.join(root, ".rolepod", "evidence")
        phase_log = os.path.join(ev_dir, "phase-log.jsonl")
        if not os.path.isfile(phase_log):
            continue
        r1, s1 = _phase_log_reviewer_counts(
            "dispatch", since_epoch, phase_log, "hook-auto", True)
        reviewers = max(reviewers, r1)
        strong = max(strong, s1)
        external += _anchored_external_count(since_epoch, ev_dir)

    if external > 0:
        reviewers += external
        strong += external

    return test_edits, high_risk_edits, reviewers, strong, external


def _external_fail_count(since_epoch, ev_dir):
    """Count of phase-log `external-fail` rows since `since_epoch` — the
    runner tried every usable cross-family member and they failed, or the
    pool was empty (python twin of precommit-gate.sh's XFAM_FAILS block,
    satellite-first, v2.76.0)."""
    import datetime
    cut = None
    if since_epoch:
        try:
            cut = datetime.datetime.fromtimestamp(float(since_epoch), datetime.timezone.utc)
        except Exception:
            cut = None
    n = 0
    try:
        with open(os.path.join(ev_dir, "phase-log.jsonl"), encoding="utf-8", errors="replace") as f:
            for line in f:
                try:
                    d = json.loads(line)
                    if not isinstance(d, dict) or d.get("phase") != "external-fail":
                        continue
                    if cut is not None:
                        ts = datetime.datetime.fromisoformat((d.get("ts") or "").replace("Z", "+00:00"))
                        if ts.tzinfo is None:
                            ts = ts.replace(tzinfo=datetime.timezone.utc)
                        if ts < cut:
                            continue
                    n += 1
                except Exception:
                    continue
    except OSError:
        pass
    return n


def gate_hold_predict(diff_dir: str) -> int:
    """External-fail row count at `diff_dir`'s window, SUMMED over every
    `_evidence_dirs(diff_dir)` root (D6, 2026-09-25: precommit-gate.sh's own
    XFAM_FAILS tally calls this same function now, not just gate-reminder.sh)
    — a usable pool with an external-fail row since the window means the
    gate's satellite-first hold does NOT apply (an internal strong reviewer
    clears it). gate-reminder.sh calls this ONLY in the one state where it
    also calls the cross-family runner (a high-risk edit, strong > 0,
    external == 0), so the reminder must not predict a block there
    (MEDIUM-4, round-1 review)."""
    diff_dir = diff_dir or "."
    since_epoch = _window_since_epoch(diff_dir)
    total = 0
    for root in _evidence_dirs(diff_dir):
        ev_dir = os.path.join(root, ".rolepod", "evidence")
        if not os.path.isfile(os.path.join(ev_dir, "phase-log.jsonl")):
            continue
        total += _external_fail_count(since_epoch, ev_dir)
    return total


def selfdo_state(transcript_path: str, target: str | None = None, root: str | None = None) -> str:
    """'<tier> <lead product edits since route> <writer dispatches since route> <route ts>'
    — "" when the Lead never wrote a routing line. One pass over the
    transcript (worktree-guard.sh calls this on every product-code edit):
    the newest routing line in the Lead's own assistant text (the shapes
    route_check.find_route accepts), then every Edit-tool call on a
    non-test code file and every WRITER_ROLE_AGENTS dispatch (Agent/Task
    subagent_type, Workflow agentType) whose timestamp is at or after it.
    Sidechain (subagent) events are skipped. `target` — the file about to be
    edited: "" unless it is product code by the same classifier that counts
    (is_product_code), so the scan runs only on a product-code edit."""
    if target is not None and not is_product_code(target, root):
        return ""
    try:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from route_check import find_route  # type: ignore
    except Exception:
        return ""
    if not transcript_path or not os.path.isfile(transcript_path):
        return ""
    # Newest-first: everything met before the routing line is at or after it
    # (the file is chronological), the message carrying the line counts its
    # own tool_use blocks, and the scan ends there instead of at byte 0.
    n_e = n_w = 0
    try:
        for ev in _iter_events_reversed(transcript_path):
            if not isinstance(ev, dict) or ev.get("isSidechain"):
                continue
            if ev.get("type") not in ("assistant", "tool_use"):
                continue
            ts = str(ev.get("timestamp") or "")[:19]
            msg = ev.get("message") if isinstance(ev.get("message"), dict) else {}
            content = msg.get("content")
            blocks = content if isinstance(content, list) else []
            if ev.get("type") == "tool_use":
                blocks = blocks + [ev]
            texts = []
            for b in blocks:
                if not isinstance(b, dict):
                    continue
                if b.get("type") == "text":
                    texts.append(str(b.get("text") or ""))
                elif b.get("type") == "tool_use":
                    tool = b.get("name") or ""
                    inp = b.get("input") or {}
                    if tool in EDIT_TOOLS:
                        if is_product_code(_file_from_input(inp), root):
                            n_e += 1
                    elif tool in AGENT_TOOLS:
                        if _bare_agent_name(inp.get("subagent_type")) in WRITER_ROLE_AGENTS:
                            n_w += 1
                    elif tool == "Workflow":
                        script = _workflow_script(inp)
                        for a in script_option_values(script, "agentType"):
                            if _bare_agent_name(a) in WRITER_ROLE_AGENTS:
                                n_w += 1
            if isinstance(content, str):
                texts.append(content)
            if ev.get("type") == "assistant" and texts:
                r = find_route("\n".join(texts))
                if r:
                    return "%s %d %d %s" % (r[0], n_e, n_w, ts or "-")
    except Exception:
        return ""
    return ""


# claim-verify-nudge.sh's prompt shapes (v2.128.0 — moved here so the hook
# reads prompt / context / session id / route freshness / auto-resume in ONE
# python spawn instead of five; the message text stays in the hook). The
# read-first NUDGE (the message) was cut v2.163.0, but its classifier still
# gates the route check below: route_check.commission_shaped only excludes
# Thai question particles and a literal "?" — an English question that also
# contains a bare commission verb ("why does the build fail", "how do we
# remove the dead code") would otherwise reach the route nudge with no gate
# at all. _QUESTION_SHAPE_RX is that classifier, kept internal-only (no
# message reads it, no extra field in prompt_state's return value) so route
# nudge's own behavior stays exactly as it was before the cut.
_QUESTION_SHAPE_RX = re.compile(
    r"(gap|gaps|root cause|diagnos|analy[sz]|audit|how does|how do|how is|how are|"
    r"why (is|does|do|are|did|isn|doesn|wasn|won|can|would)|what.?s the|"
    r"where (is|are|does|do)|is (it|this|that) (safe|correct|right|true|broken|working|wrong)|"
    r"what would break|impact of|explain (how|why|what)|why not|status of|"
    r"does (it|this|that) (work|handle|support|cause|break))", re.I)
AUTO_RESUME_RX = re.compile(r"please continue from where you left off", re.I)
# A harness background-task notification carries this tag — it is not a user
# request (the Lead did not type it), so the route check skips it the same
# way it skips a question-shaped prompt. The context-bloat check still runs
# (hook-layer-lean-2026-09-25, Route nudge).
TASK_NOTIFICATION_RX = re.compile(r"<task-notification>", re.I)


def prompt_state(d: dict) -> str:
    """'<ctx tokens> <sid|-> <has_prompt 0/1> <route stale|-> <auto 0/1>'
    for claim-verify-nudge.sh. The route check (route_check.check — the
    commission shape, the phase-log freshness and the fallback recorder)
    runs for every real prompt EXCEPT a question-shaped one
    (_QUESTION_SHAPE_RX) — the same exclusion the removed read-first nudge
    used to apply, kept so route nudge's own behavior is unchanged — and
    EXCEPT a harness background-task notification (TASK_NOTIFICATION_RX):
    not a user request, so it never carries a stale-route line."""
    prompt = str(d.get("prompt") or "")
    ctx = last_context_tokens(str(d.get("transcript_path") or ""))
    sid = re.sub(r"[^A-Za-z0-9._-]", "", str(d.get("session_id") or ""))
    if sid in (".", ".."):
        sid = ""
    route = "-"
    if prompt and not _QUESTION_SHAPE_RX.search(prompt) and not TASK_NOTIFICATION_RX.search(prompt):
        try:
            sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
            import route_check  # type: ignore
            route = route_check.check(d) or "-"
        except Exception:
            route = "-"
    auto = bool(prompt) and AUTO_RESUME_RX.search(prompt) is not None
    return "%d %s %d %s %d" % (ctx, sid or "-", 1 if prompt else 0, route, 1 if auto else 0)


_GUARD_TOOLS = ("Edit", "Write", "MultiEdit", "NotebookEdit")


def edit_fields(d: dict) -> list[str]:
    """worktree-guard.sh's parse + git root + self-do state in ONE spawn
    (v2.128.0; was three): tool, session id, cwd, agent flag, transcript,
    worktree root, self-do line, resolved target (last — read with cat).
    The self-do line is computed only where the hook would have asked for
    it: a Lead edit (no agent_id) of a product-code target with a transcript."""
    tool = str(d.get("tool_name") or "")
    sid = str(d.get("session_id") or "")
    cwd = str(d.get("cwd") or "")
    ti = d.get("tool_input") if isinstance(d.get("tool_input"), dict) else {}
    f = str(ti.get("file_path") or ti.get("notebook_path") or "")
    if f:
        base = cwd or os.getcwd()
        f = f if os.path.isabs(f) else os.path.join(base, f)
        # realpath (not abspath) so a symlinked cwd resolves the same way
        # `git rev-parse --show-toplevel` does.
        f = os.path.realpath(f)
    agent = "1" if d.get("agent_id") else ""
    tp = str(d.get("transcript_path") or "")
    root = ""
    if f and tool in _GUARD_TOOLS:
        try:
            import subprocess
            root = subprocess.run(["git", "rev-parse", "--show-toplevel"], cwd=cwd or None,
                                  capture_output=True, text=True, timeout=10).stdout.strip()
        except Exception:
            root = ""
    selfdo = ""
    if f and root and not agent and tp and os.path.isfile(tp):
        selfdo = selfdo_state(tp, f, root)
    return [tool, sid, cwd, agent, tp, root, selfdo, f]


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: session_state.py <query> [args]", file=sys.stderr)
        return 1

    query = sys.argv[1]

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
        print("%d %d %d %d" % count_all(transcript_path, since_epoch, hook_input.get("cwd")))
    elif query == "context-tokens":
        # Context size (tokens) the last assistant turn carried — 0 unknown.
        print(last_context_tokens(transcript_path))
    elif query == "gate-evidence":
        # test_edits high_risk_edits reviewers strong_reviewers external —
        # one tally shared by precommit-gate.sh and gate-reminder.sh (spec
        # Desired 2). argv[2] = the directory the window is computed at
        # (DIFF_DIR for the gate, the edited file's dir for the reminder).
        diff_dir = sys.argv[2] if len(sys.argv) > 2 else "."
        print("%d %d %d %d %d" % gate_evidence(hook_input, diff_dir))
    elif query == "gate-hold-predict":
        # external-fail row count — gate-reminder.sh's satellite-first
        # prediction (MEDIUM-4): a usable pool with an external-fail row
        # means the gate's hold does not apply, so 0 means "unknown/none".
        diff_dir = sys.argv[2] if len(sys.argv) > 2 else "."
        print(gate_hold_predict(diff_dir))
    elif query == "count-test-edits":
        print(count_test_edits(transcript_path, hook_input.get("cwd")))
    elif query == "selfdo-state":
        # "<tier> <lead product edits> <writer dispatches> <route ts>" since
        # the newest routing line — "" when no route was stated, or when
        # argv[2] (the target about to be edited) is not product code.
        target = sys.argv[2] if len(sys.argv) > 2 else None
        root = sys.argv[3] if len(sys.argv) > 3 else None
        print(selfdo_state(transcript_path, target, root))
    elif query == "prompt-state":
        # claim-verify-nudge.sh: ctx sid has_prompt route auto — one spawn.
        print(prompt_state(hook_input))
    elif query == "edit-fields":
        # worktree-guard.sh: tool / sid / cwd / agent / transcript / root /
        # self-do / target — one spawn (target last, may not be empty-safe
        # with read; the hook slurps it with cat).
        print("\n".join(edit_fields(hook_input)))
    else:
        print(f"unknown query: {query}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
