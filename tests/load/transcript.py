#!/usr/bin/env python3
# tests/load/transcript.py — read Claude Code transcripts (main session and every
# subagent layer, including subagents/workflows/) and print, per transcript, what the
# platform injected and what the agent did: agent type, run id, prompt chars, tool
# calls, skill / agent listing sizes (total and rolepod part), MCP instructions,
# words of the last message, dispatched subagent types. --paths lists every path /
# command a tool touched.
#
# Reused by: the listing trial and arm scoring of the lean-load baseline, and by P3 to
# score the dispatch experiments run after `Skill` is removed from the agents (spec
# items 4 and 16). python3 stdlib only; never part of `make test`.
#
#   python3 tests/load/transcript.py [--file <jsonl>]... [--session <id>] [--project-dir <dir>]
#       [--agent-type <t>]... [--match <regex>] [--last N] [--format tsv|json] [--paths]
#   --project-dir default: ~/.claude/projects/<absolute cwd, "/" replaced by "-">
#   --session <id>: <dir>/<id>.jsonl (agent_type "main") + <dir>/<id>/subagents/**/*.jsonl
#   --match default: p[0-9]+-[a-z]-[a-z]+-change-[ab]-r[0-9]+ (first hit in the first user message)
import argparse, glob, json, os, re, sys

COLS = ["file", "agent_type", "run", "prompt_chars", "tool_calls", "skill_listing",
        "skill_listing_rolepod", "agent_listing", "agent_listing_rolepod", "mcp",
        "final_words", "dispatched", "skill_calls", "preloaded_chars"]
DEFAULT_MATCH = r"p[0-9]+-[a-z]-[a-z]+-change-[ab]-r[0-9]+"


def agent_type_of(path, missing="main"):
    meta = path[:-len(".jsonl")] + ".meta.json"
    try:
        with open(meta, encoding="utf-8") as fh:
            return json.load(fh).get("agentType") or "?"
    except Exception:
        return missing


def lines_of(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            try:
                d = json.loads(raw)
            except Exception:
                continue
            if isinstance(d, dict):
                yield d


def rolepod_chars(lines):
    return sum(len(x) for x in lines if x.startswith("- rolepod:"))


def tool_uses(d):
    if d.get("type") != "assistant":
        return
    c = (d.get("message") or {}).get("content")
    if isinstance(c, list):
        for b in c:
            if isinstance(b, dict) and b.get("type") == "tool_use":
                yield b


RELAY_MARK = "[Workflow harness — user request]"


def is_relay(text):
    """A Workflow subagent's first user message relays the session's request; the verbatim prompt is the next one."""
    return text.startswith(RELAY_MARK)


def preloaded_chars(d, agent_type):
    """A preloaded skill reaches a named sub-agent as a user message with isMeta true whose first text
    block holds command-name>; the value is the sum of that message's text-block lengths (skill body +
    about 260). A main session or a general-purpose run (inline text in the prompt) counts 0."""
    if agent_type in ("main", "general-purpose") or d.get("type") != "user" or d.get("isMeta") is not True:
        return 0
    c = (d.get("message") or {}).get("content")
    if not isinstance(c, list):
        return 0
    texts = [b.get("text") or "" for b in c if isinstance(b, dict) and b.get("type") == "text"]
    if not texts or "command-name>" not in texts[0]:
        return 0
    return sum(len(t) for t in texts)


def scan(path, agent_type, rx):
    r = dict.fromkeys(COLS, 0)
    r.update(file=path, agent_type=agent_type, run="", final_words=0, dispatched="")
    seen, user_done, final, disp = set(), False, "", []
    for d in lines_of(path):
        a = d.get("attachment") if isinstance(d.get("attachment"), dict) else None
        if a:
            t = a.get("type")
            if t in seen:
                continue
            if t == "skill_listing":
                seen.add(t)
                c = a.get("content") or ""
                r["skill_listing"] = len(c)
                r["skill_listing_rolepod"] = rolepod_chars(c.split("\n"))
            elif t == "agent_listing_delta":
                seen.add(t)
                ls = a.get("addedLines") or []
                r["agent_listing"] = sum(len(x) for x in ls)
                r["agent_listing_rolepod"] = rolepod_chars(ls)
            elif t == "mcp_instructions_delta":
                seen.add(t)
                r["mcp"] = sum(len(x) if isinstance(x, str) else len(json.dumps(x))
                               for x in (a.get("addedBlocks") or []))
            continue
        pc = preloaded_chars(d, agent_type)
        if pc:
            r["preloaded_chars"] += pc
            continue
        if d.get("type") == "user" and not user_done:
            c = (d.get("message") or {}).get("content")
            text = c if isinstance(c, str) else json.dumps(c)
            if is_relay(text):
                continue
            user_done = True
            r["prompt_chars"] = len(text)
            m = rx.search(text)
            r["run"] = m.group(0) if m else ""
        for b in tool_uses(d):
            r["tool_calls"] += 1
            if b.get("name") == "Skill":
                r["skill_calls"] += 1
            inp = b.get("input") or {}
            if b.get("name") in ("Agent", "Task"):
                disp.append(inp.get("subagent_type") or "general-purpose")
            elif b.get("name") == "Bash" and "cross-family.sh" in str(inp.get("command", "")):
                disp.append("cross-family")
        if d.get("type") == "assistant":
            c = (d.get("message") or {}).get("content")
            if isinstance(c, list):
                for b in c:
                    if isinstance(b, dict) and b.get("type") == "text":
                        final = b.get("text") or ""
    r["final_words"] = len(final.split())
    r["dispatched"] = ",".join(disp)
    return r


def paths_of(path, run):
    out = []
    for d in lines_of(path):
        for b in tool_uses(d):
            n, i = b.get("name"), b.get("input") or {}
            if n in ("Read", "Edit", "Write"):
                vals = [i.get("file_path")]
            elif n in ("Grep", "Glob"):
                vals = [i.get("path"), i.get("pattern")]
            elif n == "Bash":
                vals = [i.get("command")]
            else:
                continue
            for v in vals:
                if v:
                    out.append((n, str(v).replace("\t", " ").replace("\n", " ")))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", action="append", default=[])
    ap.add_argument("--session")
    ap.add_argument("--project-dir")
    ap.add_argument("--agent-type", action="append", default=[])
    ap.add_argument("--match", default=DEFAULT_MATCH)
    ap.add_argument("--last", type=int)
    ap.add_argument("--format", choices=["tsv", "json"], default="tsv")
    ap.add_argument("--paths", action="store_true")
    a = ap.parse_args()
    rx = re.compile(a.match)
    items = [(f, agent_type_of(f)) for f in a.file]
    if a.session:
        pd = a.project_dir or os.path.expanduser(
            "~/.claude/projects/" + os.getcwd().replace("/", "-"))
        main_f = os.path.join(pd, a.session + ".jsonl")
        if os.path.exists(main_f):
            items.append((main_f, "main"))
        for f in sorted(glob.glob(os.path.join(pd, a.session, "subagents", "**", "*.jsonl"),
                                  recursive=True)):
            items.append((f, agent_type_of(f, "?")))
    if a.agent_type:
        items = [x for x in items if x[1] in a.agent_type]
    if a.last:
        items = sorted(items, key=lambda x: os.path.getmtime(x[0]))[-a.last:]
    if not items:
        print("no transcripts selected", file=sys.stderr)
        return 1
    rows = [scan(f, t, rx) for f, t in items]
    if a.paths:
        for r in rows:
            for tool, val in paths_of(r["file"], r["run"]):
                print("\t".join([r["file"], r["run"], tool, val]))
    elif a.format == "json":
        print(json.dumps(rows, indent=1))
    else:
        print("\t".join(COLS))
        for r in rows:
            print("\t".join(str(r[c]) for c in COLS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
