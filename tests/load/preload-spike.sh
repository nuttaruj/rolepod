#!/usr/bin/env bash
# tests/load/preload-spike.sh — does a role's preload put a skill into the dispatched sub-agent's context?
#
#   tests/load/preload-spike.sh <claude|codex|cursor|opencode|agy> [runs]     (runs default 3)
#   EV=<dir>      evidence dir (default .rolepod/evidence/preload-spike); one log per run + result.tsv
#   OC_MODEL=<provider/model>   opencode only (its default provider is the user's own)
#
# A throwaway role and a throwaway skill live in a mktemp dir. The skill holds one random SENTINEL line that
# no role text, brief or listing carries, so a sub-agent that quotes it had the skill text in its context.
# Arms: N = control (no preload), W = the CLI's own preload field, R = no preload, the role loads the skill at run time.
# result.tsv columns: cli arm run quoted child_tool_calls detail (quoted 1/0/blocked).
# Nothing here touches the repo or the user's CLI config: Codex runs under its own CODEX_HOME (auth.json symlinked, never
# copied; the mktemp dir goes on exit). Each run is one real model call per arm.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
cli="${1:-}"; runs="${2:-3}"
case "$cli" in claude|codex|cursor|opencode|agy) ;; *) echo "usage: $0 <claude|codex|cursor|opencode|agy> [runs]" >&2; exit 2 ;; esac
EV="${EV:-$PWD/.rolepod/evidence/preload-spike}"; mkdir -p "$EV/$cli"
S=$(mktemp -d); trap 'rm -rf "$S"' EXIT; TOK="SPIKE-$(python3 -c 'import uuid; print(uuid.uuid4().hex[:12])')"
echo "$cli token=$TOK" > "$EV/$cli/fixture.txt"
SKILL_MD=$'---\nname: spike-sentinel\ndescription: The spike reviewer\'s method, a throwaway skill that holds one sentinel line.\n---\n\n# Spike method\n\nSENTINEL: '"$TOK"$'\n\nStep 1. Read the diff. Step 2. Write the report.\n'
ROLE="You are a spike role. Reply with exactly one line: the full line in your context that starts with SENTINEL: copied verbatim. If no such line is in your context reply NONE. Call no tool."
ROLE_RT="You are a spike role. Your method is the skill spike-sentinel. If its text is not in your context, load the skill spike-sentinel first. Then reply with exactly one line: the full line of that skill that starts with SENTINEL: copied verbatim."
DESC="Throwaway spike role. Use only when told to."
row() { printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$cli" "$1" "$2" "$3" "$4" "$5" | tee -a "$EV/result.tsv" >/dev/null; }
head -1 "$EV/result.tsv" 2>/dev/null | grep -q '^cli' || printf 'cli\tarm\trun\tquoted\tchild_tool_calls\tdetail\n' >> "$EV/result.tsv"
ask() { echo "Dispatch the sub-agent $1 with the message 'go'. Wait for it, then print its reply verbatim, nothing else."; }

run_claude() {  # plugin agents: Q = skills: spikeplug:spike-sentinel, B = bare name, N = control
  mkdir -p "$S/plug/.claude-plugin" "$S/plug/agents" "$S/plug/skills/spike-sentinel" "$S/work"
  printf '{"name":"spikeplug","version":"0.0.1","description":"throwaway preload spike"}\n' > "$S/plug/.claude-plugin/plugin.json"
  printf '%s' "$SKILL_MD" > "$S/plug/skills/spike-sentinel/SKILL.md"
  for a in q:spikeplug:spike-sentinel b:spike-sentinel n:; do
    id=${a%%:*}; ref=${a#*:}; f="$S/plug/agents/spike-$id.md"
    { printf -- '---\nname: spike-%s\ndescription: "%s"\nmodel: haiku\ntools:\n  - Read\n' "$id" "$DESC"
      [ -n "$ref" ] && printf 'skills:\n  - %s\n'  "$ref"
      printf -- '---\n%s\n' "$ROLE"; } > "$f"
  done
  for id in q b n; do for k in $(seq 1 "$runs"); do
    sid=$(python3 -c 'import uuid; print(uuid.uuid4())'); log="$EV/claude/$id.r$k.jsonl"
    (cd "$S/work" && claude -p --model haiku --plugin-dir "$S/plug" --setting-sources project --allowedTools Agent \
      --output-format stream-json --verbose --session-id "$sid" "$(ask "spikeplug:spike-$id")" < /dev/null > "$log" 2> "$log.err")
    python3 - "$log" "$sid" "$TOK" <<'PY' | { IFS=$'\t' read -r q tc det; row "$id" "$k" "$q" "$tc" "$det"; }
import glob, json, os, sys
log, sid, tok = sys.argv[1:4]
res = [json.loads(l) for l in open(log) if l.startswith("{")]
final = " ".join(r.get("result", "") for r in res if r.get("type") == "result")
subs = glob.glob(os.path.expanduser("~/.claude/projects/*/%s/subagents/agent-*.jsonl" % sid))
calls, base, pre = 0, 0, 0
for p in subs:
    for l in open(p):
        d = json.loads(l); c = (d.get("message") or {}).get("content")
        if isinstance(c, list):
            for b in c:
                if b.get("type") == "tool_use": calls += 1
                if d.get("isMeta") and b.get("type") == "text":
                    if "command-name>" in b["text"]: pre += len(b["text"])
                    if "Base directory for this skill" in b["text"]: base = 1; pre += len(b["text"])
quoted = "1" if ("SENTINEL: " + tok) in final else ("blocked" if not res else "0")
print("%s\t%d\tpreloaded_chars=%d base_dir_line=%d subagent_files=%d" % (quoted, calls, pre, base, len(subs)))
PY
  done; done
}

run_codex() {  # W = [[skills.config]] path+enabled in the role TOML (what the docs promise), I = body inlined, N = control
  CH="$S/codex-home"; mkdir -p "$CH/agents" "$S/cw/skills/spike-sentinel"; ln -s "$HOME/.codex/auth.json" "$CH/auth.json"
  printf '%s' "$SKILL_MD" > "$S/cw/skills/spike-sentinel/SKILL.md"; (cd "$S/cw" && git init -q .)
  printf 'model_reasoning_effort = "low"\n' > "$CH/config.toml"
  body=$(printf '%s' "$SKILL_MD" | python3 -c 'import sys; print(sys.stdin.read().split("\n---\n",1)[1].strip())')
  printf 'name = "spikew"\ndescription = "%s"\ndeveloper_instructions = """\n%s\n"""\n\n[[skills.config]]\npath = "%s"\nenabled = true\n' "$DESC" "$ROLE" "$S/cw/skills/spike-sentinel/SKILL.md" > "$CH/agents/spikew.toml"
  printf 'name = "spikei"\ndescription = "%s"\ndeveloper_instructions = """\n%s\n\n<preloaded_skill name="spike-sentinel">\n%s\n</preloaded_skill>\n"""\n' "$DESC" "$ROLE" "$body" > "$CH/agents/spikei.toml"
  printf 'name = "spiken"\ndescription = "%s"\ndeveloper_instructions = """\n%s\n"""\n' "$DESC" "$ROLE" > "$CH/agents/spiken.toml"
  for id in w i n; do for k in $(seq 1 "$runs"); do
    log="$EV/codex/$id.r$k.jsonl"
    (cd "$S/cw" && CODEX_HOME="$CH" codex exec --skip-git-repo-check --json -C "$S/cw" \
      "Use spawn_agent with agent_type spike$id and message 'go'. Wait for it and print its reply verbatim, nothing else." < /dev/null > "$log" 2> "$log.err")
    python3 - "$log" "$TOK" <<'PY' | { IFS=$'\t' read -r q det; row "$id" "$k" "$q" "-" "$det"; }
import json, sys
log, tok = sys.argv[1:3]
msgs = [json.loads(l)["item"]["text"] for l in open(log) if l.startswith("{") and '"agent_message"' in l]
q = "1" if msgs and ("SENTINEL: " + tok) in msgs[-1] else ("blocked" if not msgs else "0")
print("%s\tfinal=%s" % (q, (msgs[-1] if msgs else "")[:60].replace("\n", " ")))
PY
  done; done
}

run_cursor() {  # P = a skills: key in the role file (ignored by Cursor's parser), R = runtime load, N = control
  W="$S/cur"; mkdir -p "$W/.cursor/agents" "$W/.cursor/skills/spike-sentinel"; (cd "$W" && git init -q .)
  printf '%s' "$SKILL_MD" > "$W/.cursor/skills/spike-sentinel/SKILL.md"
  printf -- '---\nname: spikep\ndescription: %s\nreadonly: true\nskills:\n  - spike-sentinel\n---\n%s Do not read any file.\n' "$DESC" "$ROLE" > "$W/.cursor/agents/spikep.md"
  printf -- '---\nname: spiker\ndescription: %s\nreadonly: true\n---\n%s\n' "$DESC" "$ROLE_RT" > "$W/.cursor/agents/spiker.md"
  printf -- '---\nname: spiken\ndescription: %s\nreadonly: true\n---\n%s Do not read any file.\n' "$DESC" "$ROLE" > "$W/.cursor/agents/spiken.md"
  for id in p r n; do for k in $(seq 1 "$runs"); do
    log="$EV/cursor/$id.r$k.jsonl"
    (cd "$W" && agent -p --trust --force --model auto --workspace "$W" --output-format stream-json "$(ask "spike$id")" < /dev/null > "$log" 2> "$log.err")
    python3 - "$log" "$TOK" <<'PY' | { IFS=$'\t' read -r q det; row "$id" "$k" "$q" "-" "$det"; }
import json, sys
log, tok = sys.argv[1:3]
rows = [json.loads(l) for l in open(log) if l.startswith("{")]
def is_task(r, sub):
    return r.get("type") == "tool_call" and r.get("subtype") == sub and "taskToolCall" in r.get("tool_call", {})
sent = [r for r in rows if is_task(r, "started")]
task = [r for r in rows if is_task(r, "completed")]
brief = json.dumps([r["tool_call"]["taskToolCall"].get("args", {}) for r in sent])
q = "blocked" if not task else ("contaminated" if tok in brief else ("1" if ("SENTINEL: " + tok) in json.dumps(task[-1]) else "0"))
print("%s\ttask_calls=%d token_in_brief=%d" % (q, len(task), int(tok in brief)))
PY
  done; done
}

run_opencode() {  # P = a skills: key (no such field in Agent.Info), R = runtime load, N = control
  [ -n "${OC_MODEL:-}" ] || { row all 0 blocked - "set OC_MODEL=<provider/model>; the default provider failed at HEAD drafting"; return; }
  W="$S/oc"; mkdir -p "$W/.opencode/agents" "$W/.opencode/skills/spike-sentinel"; (cd "$W" && git init -q .)
  printf '%s' "$SKILL_MD" > "$W/.opencode/skills/spike-sentinel/SKILL.md"
  printf -- '---\ndescription: %s\nmode: subagent\nskills:\n  - spike-sentinel\n---\n%s Do not read any file.\n' "$DESC" "$ROLE" > "$W/.opencode/agents/spikep.md"
  printf -- '---\ndescription: %s\nmode: subagent\n---\n%s\n' "$DESC" "$ROLE_RT" > "$W/.opencode/agents/spiker.md"
  printf -- '---\ndescription: %s\nmode: subagent\n---\n%s Do not read any file.\n' "$DESC" "$ROLE" > "$W/.opencode/agents/spiken.md"
  for id in p r n; do for k in $(seq 1 "$runs"); do
    log="$EV/opencode/$id.r$k.jsonl"
    (cd "$W" && opencode run --standalone --auto --format json -m "$OC_MODEL" "$(ask "spike$id")" < /dev/null > "$log" 2> "$log.err")
    if grep -q '"type": *"error"' "$log"; then row "$id" "$k" blocked - "provider error in $log"; continue; fi
    if grep -q "SENTINEL: $TOK" "$log"; then row "$id" "$k" 1 - "token in output"; else row "$id" "$k" 0 - "no token"; fi
  done; done
}

run_agy() {  # W-rel / W-name = skills: with an agent-relative path / a bare name, N = control; the agent runs as the session agent
  W="$S/agy"; mkdir -p "$W/.agents/agents" "$W/.agents/skills/spike-sentinel"; (cd "$W" && git init -q .)
  printf '%s' "$SKILL_MD" > "$W/.agents/skills/spike-sentinel/SKILL.md"
  for a in rel:../skills/spike-sentinel name:spike-sentinel n:; do
    id=${a%%:*}; ref=${a#*:}
    { printf -- '---\nname: spike-%s\ndescription: "%s"\ninheritCustomizations: false\n' "$id" "$DESC"
      [ -n "$ref" ] && printf 'skills:\n  - %s\n' "$ref"
      printf -- '---\n%s\n' "$ROLE"; } > "$W/.agents/agents/spike-$id.md"
  done
  for id in rel name n; do for k in $(seq 1 "$runs"); do
    log="$EV/agy/$id.r$k.txt"
    (cd "$W" && agy --agent "spike-$id" --print "go" --output-format text < /dev/null > "$log" 2>&1)
    if grep -q 'credits balance is too low\|RESOURCE_EXHAUSTED' "$log"; then row "$id" "$k" blocked - "agy credits exhausted"; continue; fi
    if grep -q "SENTINEL: $TOK" "$log"; then row "$id" "$k" 1 - "token in reply"; else row "$id" "$k" 0 - "no token"; fi
  done; done
  # static arm: the rendered agy plugin plus a skills: line on one agent must still pass `agy plugin validate` (parse only, no model call)
  cp -R build/rendered/antigravity/plugin "$S/agyplug" && python3 - "$S/agyplug/agents/universal-reviewer.md" <<'PY'
import sys
p = sys.argv[1]; t = open(p).read()
open(p, "w").write(t.replace("\n---\n", "\nskills:\n  - ../skills/review-code\n---\n", 1))
PY
  if agy plugin validate "$S/agyplug" 2>&1 | grep -Eq 'agents *: [0-9]+ processed'; then row static 0 1 - "validate accepts skills: on an agent (parse only)"; else row static 0 0 - "validate rejects skills: on an agent"; fi
}

"run_$cli"
echo "wrote $EV/result.tsv (fixture dir removed on exit)"
