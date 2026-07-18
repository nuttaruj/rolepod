#!/usr/bin/env python3
"""rolepod agent merger.

Reassembles a target-flavored agent file from:
  - core/agents/<name>.md   (portable: name/description/color + body)
  - adapter-specific frontmatter overlay

Usage:
  merge-agent.py --target=claude --name=qa-tester  (md — model/effort overlay)
  merge-agent.py --target=codex  --name=qa-tester  (toml — model/sandbox overlay)
  merge-agent.py --target=gemini --name=qa-tester  (md — model overlay)
  merge-agent.py --target=cursor --name=qa-tester  (md — minimal name+description only)

Writes to stdout. Render driver pipes into the per-target rendered/ directory.

Field order in emitted frontmatter matches the original Claude agent files so
the Claude target output is byte-identical to the pre-split source.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Field order for re-emission.
CLAUDE_KEY_ORDER = ["name", "description", "model", "effort", "memory",
                    "maxTurns", "permissionMode", "color", "skills", "tools"]
GEMINI_KEY_ORDER = ["name", "description", "model"]
CURSOR_KEY_ORDER = ["name", "description"]
# Codex agents are TOML, not frontmatter — see emit_codex_toml().

REPO_DIR = Path(__file__).resolve().parent.parent


def parse_yaml_block(text: str) -> dict[str, list[str]]:
    """Parse simple key/value + list-style YAML into ordered field map.

    Returns dict mapping key -> list of raw lines (key line first, then any
    `  - item` continuations).
    """
    fields: dict[str, list[str]] = {}
    current: str | None = None
    for line in text.split("\n"):
        if not line:
            continue
        # Skip comment lines (full-line YAML comments only).
        if line.lstrip().startswith("#"):
            continue
        if line.startswith("  -") or line.startswith("\t-"):
            if current is None:
                raise ValueError(f"orphan list item: {line!r}")
            fields[current].append(line)
            continue
        m = re.match(r"^([A-Za-z][A-Za-z0-9_]*):\s*(.*)$", line)
        if not m:
            raise ValueError(f"unparseable yaml line: {line!r}")
        current = m.group(1)
        if m.group(2):
            fields[current] = [line]
        else:
            fields[current] = [line]
    return fields


def split_core_agent(text: str) -> tuple[dict[str, list[str]], str]:
    """Split core/agents/<name>.md into (frontmatter fields, body)."""
    if not text.startswith("---\n"):
        raise ValueError("missing leading --- delimiter")
    rest = text[4:]
    end = rest.find("\n---\n")
    if end == -1:
        raise ValueError("missing closing --- delimiter")
    fm = rest[:end]
    body = rest[end + len("\n---\n"):]
    return parse_yaml_block(fm), body


def resolve_includes(text: str) -> str:
    """Replace `{{INCLUDE: <path>}}` directive lines with the file's contents.

    Lets an agent body pull a shared fragment (e.g. agent-protocol.md) instead
    of restating it. Mirrors render_template's directive in build/render.sh.
    """
    out: list[str] = []
    for line in text.split("\n"):
        m = re.match(r"^\{\{INCLUDE: (.+)\}\}$", line)
        if m:
            inc = REPO_DIR / m.group(1)
            if not inc.exists():
                raise FileNotFoundError(f"missing include {m.group(1)}")
            out.append(inc.read_text().rstrip("\n"))
        else:
            out.append(line)
    return "\n".join(out)


def emit(keys_in_order: list[str], fields: dict[str, list[str]]) -> str:
    out: list[str] = []
    for key in keys_in_order:
        if key in fields:
            out.extend(fields[key])
    return "\n".join(out) + "\n"


def field_value(fields: dict[str, list[str]], key: str) -> str:
    """Scalar value of a simple `key: value` field."""
    return fields[key][0].split(":", 1)[1].strip()


def emit_codex_toml(fields: dict[str, list[str]], body: str) -> str:
    """Emit a Codex agent TOML — name/description from core, model /
    model_reasoning_effort / sandbox_mode from the Codex overlay, and the
    core agent body as the developer_instructions multiline string.

    Agent bodies are plain markdown — no backslash, no `\"\"\"` — so the body
    drops straight into a TOML basic multiline string without escaping.
    """
    out = [
        f'name = "{field_value(fields, "name")}"',
        f'description = "{field_value(fields, "description")}"',
        f'model = "{field_value(fields, "model")}"',
        f'model_reasoning_effort = "{field_value(fields, "model_reasoning_effort")}"',
        f'sandbox_mode = "{field_value(fields, "sandbox_mode")}"',
        'developer_instructions = """',
        body.rstrip("\n"),
        '"""',
    ]
    return "\n".join(out) + "\n"


def merge(target: str, name: str) -> str:
    core_path = REPO_DIR / "core" / "agents" / f"{name}.md"
    if not core_path.exists():
        raise FileNotFoundError(f"missing {core_path}")
    core_fields, body = split_core_agent(core_path.read_text())
    body = resolve_includes(body)

    if target == "claude":
        overlay_path = REPO_DIR / "adapters" / "claude" / "agent-frontmatter" / f"{name}.yml"
        if not overlay_path.exists():
            raise FileNotFoundError(f"missing {overlay_path}")
        overlay = parse_yaml_block(overlay_path.read_text())
        merged = {**core_fields, **overlay}
        # Re-order to match Claude original
        return "---\n" + emit(CLAUDE_KEY_ORDER, merged) + "---\n" + body

    if target == "codex":
        # Codex agents are TOML in ~/.codex/agents/. Generated from the same
        # core/agents body as Claude/Gemini — no separate hand-maintained copy.
        overlay_path = REPO_DIR / "adapters" / "codex" / "agent-frontmatter" / f"{name}.yml"
        if not overlay_path.exists():
            raise FileNotFoundError(f"missing {overlay_path}")
        overlay = parse_yaml_block(overlay_path.read_text())
        merged = {**core_fields, **overlay}
        return emit_codex_toml(merged, body)

    if target == "gemini":
        # Gemini extension ships agents/<name>.md (md + YAML frontmatter).
        # Overlay carries the tier-mapped `model:`; no effort field on Gemini.
        overlay_path = REPO_DIR / "adapters" / "gemini" / "agent-frontmatter" / f"{name}.yml"
        if not overlay_path.exists():
            raise FileNotFoundError(f"missing {overlay_path}")
        overlay = parse_yaml_block(overlay_path.read_text())
        merged = {**core_fields, **overlay}
        return "---\n" + emit(GEMINI_KEY_ORDER, merged) + "---\n" + body

    if target == "cursor":
        # Cursor agents ship agents/<name>.md with minimal frontmatter — the
        # documented spec only acknowledges `name` and `description`. We drop
        # Claude's model / effort / color / tools / skills fields rather than
        # gambling on Cursor tolerating unknown keys (the official
        # plugin-template uses minimal frontmatter only).
        # No overlay needed: name + description already live in core/agents.
        return "---\n" + emit(CURSOR_KEY_ORDER, core_fields) + "---\n" + body

    raise ValueError(f"unknown target: {target}")


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--target", required=True, choices=["claude", "codex", "gemini", "cursor"])
    p.add_argument("--name", required=True)
    args = p.parse_args()
    sys.stdout.write(merge(args.target, args.name))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
