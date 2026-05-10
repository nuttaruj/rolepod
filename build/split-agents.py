#!/usr/bin/env python3
"""rolepod agent splitter.

Reads agents/<name>.md (Claude-flavored frontmatter + portable body), splits
into:
  - core/agents/<name>.md            : portable frontmatter (name/description/color) + body
  - adapters/claude/agent-frontmatter/<name>.yml : Claude-specific frontmatter keys

Run once during Phase 2.2 migration to populate the new layout. After this
runs and renderer reassembles byte-identical output, the legacy agents/*.md
can be deleted (regenerated on demand by render.sh).

The script is idempotent — re-running overwrites the split outputs.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Order matters when re-emitting frontmatter to keep output deterministic.
# Field order chosen to match observed agent files so re-render is byte-identical.
PORTABLE_KEYS = ["name", "description", "color"]
CLAUDE_KEYS = ["model", "effort", "memory", "maxTurns", "permissionMode", "skills", "tools"]
ALL_KEYS = ["name", "description", "model", "effort", "memory", "maxTurns",
            "permissionMode", "color", "skills", "tools"]


def parse_frontmatter(text: str) -> tuple[dict[str, list[str]], str]:
    """Split YAML frontmatter from body. Returns (fields_in_order, body).

    fields_in_order is a list of (key, raw_value_lines) preserving original
    order and exact formatting. We don't use a YAML parser to avoid adding a
    dependency and because frontmatter shape is uniform/simple here.
    """
    if not text.startswith("---\n"):
        raise ValueError("missing leading --- frontmatter delimiter")
    rest = text[4:]
    end = rest.find("\n---\n")
    if end == -1:
        raise ValueError("missing closing --- delimiter")
    fm_text = rest[:end]
    body = rest[end + len("\n---\n"):]

    # Parse line-by-line, grouping list continuations with their key.
    fields: dict[str, list[str]] = {}
    current_key: str | None = None
    for line in fm_text.split("\n"):
        if not line:
            continue
        if line.startswith("  -") or line.startswith("\t-"):
            # List item — append to current key
            if current_key is None:
                raise ValueError(f"orphan list item: {line!r}")
            fields[current_key].append(line)
            continue
        m = re.match(r"^([A-Za-z][A-Za-z0-9]*):\s*(.*)$", line)
        if not m:
            raise ValueError(f"unparseable frontmatter line: {line!r}")
        key = m.group(1)
        value = m.group(2)
        current_key = key
        if value:
            fields[key] = [f"{key}: {value}"]
        else:
            fields[key] = [f"{key}:"]
    return fields, body


def emit_yaml_block(keys_in_order: list[str], fields: dict[str, list[str]]) -> str:
    out: list[str] = []
    for key in keys_in_order:
        if key in fields:
            out.extend(fields[key])
    return "\n".join(out) + "\n"


def split_agent(agent_path: Path, core_dir: Path, adapter_dir: Path) -> None:
    text = agent_path.read_text()
    fields, body = parse_frontmatter(text)
    name = agent_path.stem

    # Portable: write core/agents/<name>.md with name/description/color frontmatter + body.
    # Body already starts with the original blank line that followed "---" — avoid
    # adding a second blank line so render-time concat is byte-identical to source.
    portable = "---\n" + emit_yaml_block(PORTABLE_KEYS, fields) + "---\n" + body
    core_out = core_dir / f"{name}.md"
    core_out.write_text(portable)

    # Claude-specific: write adapters/claude/agent-frontmatter/<name>.yml (no fences)
    claude_yaml = emit_yaml_block(CLAUDE_KEYS, fields)
    adapter_out = adapter_dir / f"{name}.yml"
    adapter_out.write_text(claude_yaml)


def main(argv: list[str]) -> int:
    repo_dir = Path(__file__).resolve().parent.parent
    src_dir = repo_dir / "agents"
    core_dir = repo_dir / "core" / "agents"
    adapter_dir = repo_dir / "adapters" / "claude" / "agent-frontmatter"

    core_dir.mkdir(parents=True, exist_ok=True)
    adapter_dir.mkdir(parents=True, exist_ok=True)

    agents = sorted(src_dir.glob("*.md"))
    if not agents:
        print(f"no agents found in {src_dir}", file=sys.stderr)
        return 1

    for a in agents:
        split_agent(a, core_dir, adapter_dir)
        print(f"split: {a.name}")
    print(f"\n{len(agents)} agents split → core/agents/ + adapters/claude/agent-frontmatter/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
