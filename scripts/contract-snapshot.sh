#!/bin/bash
# contract-snapshot — the facts rolepod's hooks and tier pins depend on,
# read from the installed CLI binaries and diffed against a committed
# snapshot (v2.128.0).
#
# Why: every rolepod hook writes to a contract it never verified — hook
# event names, hookSpecificOutput keys, tool names, model ids, Codex's
# effort enum and spawn_agent parameters. Each of those has moved under
# us (Task → Agent, SubagentStart appearing on Codex, gpt-5.6-* pins,
# `ultra`/`max` effort) and every move was found by hand with `strings`.
# This script derives the same facts mechanically and `make doctor` diffs
# them, so an upgrade that moves the contract is one line of output, not
# an incident. The snapshot pins the version the facts were reviewed at.
#
# Exit codes (the gate never looks green when it could not look):
#   0  OK             every fact matches the snapshot (version may differ)
#   1  DRIFT          a fact set gained or lost members — review, then --update
#   2  CANNOT-OBSERVE the binary or the snapshot was not found — nothing verified
#   3  usage
#
#   bash scripts/contract-snapshot.sh --check              # both CLIs (skips one that is not installed → CANNOT-OBSERVE for it)
#   bash scripts/contract-snapshot.sh --update             # rewrite tests/contract/<cli>.snapshot from the installed binaries
#   bash scripts/contract-snapshot.sh --print --cli codex  # show the derived facts
#   --from-strings FILE --version V   read facts from a strings(1) dump instead of a binary (tests)
#   --snapshot FILE                   compare against / write this file instead of tests/contract/<cli>.snapshot
set -uo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v python3 >/dev/null 2>&1 || { echo "contract-snapshot: python3 required"; exit 2; }
REPO_DIR="$REPO_DIR" python3 -I - "$@" <<'PY'
import datetime, os, re, shutil, subprocess, sys

REPO = os.environ["REPO_DIR"]
KNOWN = {
  "claude": {
    "hook_events": "SessionStart SessionEnd UserPromptSubmit UserPromptExpansion PreToolUse PostToolUse PostToolUseFailure PostToolBatch PermissionRequest PermissionDenied Notification Stop StopFailure SubagentStart SubagentStop PreCompact PostCompact Setup TeammateIdle TaskCreated TaskCompleted Elicitation ElicitationResult CwdChanged FileChanged DirectoryAdded WorktreeRemove PreModelSwitch PostModelSwitch InstructionsLoaded ConfigChange MessageDisplay".split(),
    "output_keys": "hookSpecificOutput hookEventName additionalContext permissionDecision permissionDecisionReason updatedInput systemMessage suppressOutput stopReason updatedPermissions updatedMCPToolOutput".split(),
    "tool_names": "Agent Workflow FileRead FileEdit FileWrite NotebookEdit Bash Grep Glob WebFetch WebSearch Skill ToolSearch SendMessage Monitor ListAgents".split(),
  },
  "codex": {
    "hook_events": "SessionStart SessionEnd UserPromptSubmit PreToolUse PostToolUse PermissionRequest PreCompact PostCompact SubagentStart SubagentStop Stop Interrupt Notification".split(),
    "collab_tools": "spawn_agent send_message followup_task wait_agent list_agents close_agent interrupt_agent resume_agent send_input spawn_agents_on_csv".split(),
    "effort_levels": "minimal low medium high xhigh max ultra".split(),
    "agents_keys": "enabled default_subagent_model default_subagent_reasoning_effort max_concurrent_threads_per_session max_threads interrupt_message".split(),
    "spawn_params": "task_name agent_type fork_turns nickname model reasoning_effort".split(),
  },
}

def usage(rc=3):
    print("usage: contract-snapshot.sh (--check|--update|--print) [--cli claude|codex] [--from-strings FILE --version V] [--snapshot FILE]", file=sys.stderr)
    sys.exit(rc)

args = sys.argv[1:]
mode = None; cli = None; from_strings = None; version = None; snap_override = None
i = 0
while i < len(args):
    a = args[i]
    if a in ("--check", "--update", "--print"): mode = a[2:]
    elif a == "--cli": i += 1; cli = args[i]
    elif a == "--from-strings": i += 1; from_strings = args[i]
    elif a == "--version": i += 1; version = args[i]
    elif a == "--snapshot": i += 1; snap_override = args[i]
    else: usage()
    i += 1
if mode is None: usage()
clis = [cli] if cli else ["claude", "codex"]
if from_strings and not cli: usage()

def big_file_near(cli, path, min_mb=5):
    """The real binary: the resolved launcher when it is big, else the largest
    big file under the launcher's package named after the CLI (npm packages
    ship a small .js shim next to a vendored native binary)."""
    try:
        if os.path.getsize(path) > min_mb * 1e6: return path
    except OSError:
        return None
    pkg = os.path.dirname(os.path.dirname(os.path.realpath(path)))
    best = None
    for base, _d, files in os.walk(pkg):
        for fn in files:
            if not (fn == cli or fn.startswith(cli + ".") or fn == "cli.js"): continue
            fp = os.path.join(base, fn)
            try: sz = os.path.getsize(fp)
            except OSError: continue
            if sz > min_mb * 1e6 and (best is None or sz > best[0]): best = (sz, fp)
    return best[1] if best else None

def locate(cli):
    exe = shutil.which(cli)
    if not exe: return None, "not on PATH"
    return big_file_near(cli, os.path.realpath(exe)), None

def cli_version(cli):
    try:
        out = subprocess.run([cli, "--version"], capture_output=True, text=True, timeout=20).stdout
        m = re.search(r"\d+\.\d+\.\d+", out)
        return m.group(0) if m else out.strip()[:40]
    except Exception:
        return "?"

def strings_of(path):
    if shutil.which("strings"):
        try:
            return subprocess.run(["strings", path], capture_output=True, text=True, errors="replace", timeout=300).stdout
        except Exception:
            pass
    with open(path, "rb") as f:
        data = f.read()
    return "\n".join(m.group(0).decode("ascii", "replace") for m in re.finditer(rb"[\x20-\x7e]{6,}", data))

def present(text, names):
    return sorted(n for n in names if re.search(r"(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])" % re.escape(n), text))

def facts_for(cli, text):
    k = KNOWN[cli]; out = {}
    if cli == "claude":
        out["hook_events"] = present(text, k["hook_events"])
        out["output_keys"] = present(text, k["output_keys"])
        # The tools rolepod hooks match on, by their class-name spelling
        # (`AgentTool`, `BashTool`, ...): a rename here breaks a matcher.
        out["tool_names"] = present(text, [t + "Tool" for t in k["tool_names"]])
        # Short model ids of the families rolepod's tier docs name; dated /
        # -v1 variants are noise, a new family or a retired one is the signal.
        out["model_ids"] = sorted(set(re.findall(r"\bclaude-(?:opus|sonnet|haiku|fable)-\d(?:-\d)?\b", text)))
    else:
        out["hook_events"] = present(text, k["hook_events"])
        out["collab_tools"] = present(text, k["collab_tools"])
        out["effort_levels"] = present(text, k["effort_levels"])
        out["agents_keys"] = present(text, k["agents_keys"])
        out["spawn_params"] = present(text, k["spawn_params"])
        # Clean ids only: strings(1) glues neighbouring literals together, so
        # a family suffix must end the token ("gpt-5.6-lunacodex" is noise).
        out["model_ids"] = sorted(set(re.findall(
            r"\bgpt-\d+(?:\.\d+)*(?:-(?:luna|terra|sol|astra|pro|mini|nano|codex))?(?![A-Za-z0-9.-])", text)))
    return out

def render(cli, version, facts):
    lines = ["# rolepod CLI contract snapshot -- %s -- taken at %s on %s (this line is informational, not diffed)"
             % (cli, version, datetime.date.today().isoformat())]
    for key in sorted(facts):
        lines.append("%s: %s" % (key, " ".join(facts[key])))
    return "\n".join(lines) + "\n"

def parse(snapshot_text):
    facts = {}; taken = "?"
    for line in snapshot_text.splitlines():
        if line.startswith("#"):
            m = re.search(r"taken at (\S+)", line)
            if m: taken = m.group(1)
            continue
        if ":" in line:
            key, _, val = line.partition(":")
            facts[key.strip()] = val.split()
    return facts, taken

worst = 0
for c in clis:
    snap = snap_override or os.path.join(REPO, "tests", "contract", c + ".snapshot")
    if from_strings:
        try: text = open(from_strings, errors="replace").read()
        except OSError:
            print("CANNOT-OBSERVE %s: strings file not readable: %s" % (c, from_strings)); worst = max(worst, 2); continue
        ver = version or "?"
    else:
        binary, why = locate(c)
        if not binary:
            print("CANNOT-OBSERVE %s: %s -- nothing verified" % (c, why or "binary not found next to the launcher")); worst = max(worst, 2); continue
        ver = cli_version(c)
        text = strings_of(binary)
    facts = facts_for(c, text)
    if mode == "print":
        sys.stdout.write(render(c, ver, facts)); continue
    if mode == "update":
        os.makedirs(os.path.dirname(snap), exist_ok=True)
        open(snap, "w").write(render(c, ver, facts))
        print("UPDATED %s %s -> %s (%s)" % (c, ver, os.path.relpath(snap, REPO), ", ".join("%s=%d" % (k, len(v)) for k, v in sorted(facts.items()))))
        continue
    if not os.path.isfile(snap):
        print("CANNOT-OBSERVE %s: no snapshot at %s -- run --update once" % (c, os.path.relpath(snap, REPO))); worst = max(worst, 2); continue
    old, taken = parse(open(snap).read())
    drift = []
    for key in sorted(set(old) | set(facts)):
        a, b = set(old.get(key, [])), set(facts.get(key, []))
        if a != b:
            drift.append("%s: +%s -%s" % (key, ",".join(sorted(b - a)) or "-", ",".join(sorted(a - b)) or "-"))
    if drift:
        print("DRIFT %s %s (snapshot taken at %s): %s -- review, then: make contract-update" % (c, ver, taken, "; ".join(drift))); worst = max(worst, 1)
    else:
        print("OK %s %s: %d fact sets unchanged (snapshot taken at %s)" % (c, ver, len(facts), taken))
sys.exit(worst)
PY
