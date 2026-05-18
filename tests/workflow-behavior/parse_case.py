#!/usr/bin/env python3
"""
Minimal YAML parser for workflow-behavior case files.

Schema (per tests/workflow-behavior/README.md):
  name:              <kebab-case>
  prompt: |          <multi-line literal block>
  expected_skills:   <list of strings>      # substrings that MUST appear (skill routing)
  must_contain:      <list of strings>      # substrings that MUST appear (positive content)
  must_not_contain:  <list of strings>      # substrings that MUST NOT appear
  why: |             <optional rationale block>

`expected_skills` and `must_contain` are both positive substring assertions;
they're kept separate so it's clear from the case file whether an assertion
is about routing (skill name) or about agent content (questions, options, etc).

Output: JSON on stdout with normalized fields.

Designed to avoid a PyYAML dependency. The schema is small enough that a
plain line-based parser covers it. If we add nested structures later,
swap this for `yaml.safe_load`.
"""
from __future__ import annotations

import json
import sys


def parse_case(path: str) -> dict:
    with open(path) as f:
        raw = f.read()

    out = {
        "name": "",
        "prompt": "",
        "expected_skills": [],
        "must_contain": [],
        "must_not_contain": [],
        "why": "",
    }
    section = None
    buf: list[str] = []

    def flush_block(target_key: str) -> None:
        nonlocal buf
        if buf:
            out[target_key] = "\n".join(buf).strip()
        buf = []

    for line in raw.splitlines():
        if line.startswith("name:"):
            if section in ("prompt", "why"):
                flush_block(section)
            out["name"] = line.split(":", 1)[1].strip().strip("'\"")
            section = None
        elif line.startswith("prompt:"):
            if section in ("prompt", "why"):
                flush_block(section)
            section = "prompt"
            buf = []
        elif line.startswith("expected_skills:"):
            if section in ("prompt", "why"):
                flush_block(section)
            section = "expected_skills"
        elif line.startswith("must_contain:"):
            if section in ("prompt", "why"):
                flush_block(section)
            section = "must_contain"
        elif line.startswith("must_not_contain:"):
            if section in ("prompt", "why"):
                flush_block(section)
            section = "must_not_contain"
        elif line.startswith("why:"):
            if section in ("prompt", "why"):
                flush_block(section)
            section = "why"
            buf = []
        elif section == "prompt":
            buf.append(line[2:] if line.startswith("  ") else line)
        elif section == "expected_skills" and line.lstrip().startswith("-"):
            out["expected_skills"].append(line.lstrip("- ").strip().strip("'\""))
        elif section == "must_contain" and line.lstrip().startswith("-"):
            out["must_contain"].append(line.lstrip("- ").strip().strip("'\""))
        elif section == "must_not_contain" and line.lstrip().startswith("-"):
            out["must_not_contain"].append(line.lstrip("- ").strip().strip("'\""))
        elif section == "why":
            buf.append(line[2:] if line.startswith("  ") else line)

    if section in ("prompt", "why"):
        flush_block(section)

    return out


def check_assertions(
    expected_json: str,
    must_contain_json: str,
    forbidden_json: str,
    response: str,
) -> tuple[str, str, str]:
    expected = json.loads(expected_json)
    must_contain = json.loads(must_contain_json)
    forbidden = json.loads(forbidden_json)
    haystack = response.lower()
    missing_expected = ",".join(s for s in expected if s.lower() not in haystack)
    missing_required = ",".join(s for s in must_contain if s.lower() not in haystack)
    found_forbidden = ",".join(s for s in forbidden if s.lower() in haystack)
    return missing_expected, missing_required, found_forbidden


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: parse_case.py <case.yml>", file=sys.stderr)
        print("       parse_case.py assert <expected-json> <must-contain-json> <forbidden-json> <response-file>", file=sys.stderr)
        return 2

    cmd = sys.argv[1]

    if cmd == "assert":
        if len(sys.argv) != 6:
            print("usage: parse_case.py assert <expected-json> <must-contain-json> <forbidden-json> <response-file>", file=sys.stderr)
            return 2
        with open(sys.argv[5]) as f:
            response = f.read()
        missing_expected, missing_required, found_forbidden = check_assertions(
            sys.argv[2], sys.argv[3], sys.argv[4], response
        )
        # Three lines: missing-expected, missing-required, found-forbidden. Empty lines = pass.
        print(missing_expected)
        print(missing_required)
        print(found_forbidden)
        return 0

    # Default: parse case file.
    parsed = parse_case(cmd)
    json.dump(parsed, sys.stdout)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
