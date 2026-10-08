#!/usr/bin/env bash
# tests/probes/run.sh — a one-turn probe of a rendered skill on a cheap model.
#
# Not a harness and never part of `make test`: one probe costs ~25k tokens
# (the skill text is inlined). Run it by hand after editing an exit / branch
# line of a skill, read the answer, compare with the case's expect / forbid
# lines. A wrong STOP / CONTINUE is a text defect to fix in the skill.
#
#   tests/probes/run.sh <case-id|all>        cases live in tests/probes/cases/
#   tests/probes/run.sh --dry-run <case-id>  print the prompt, call nothing
#   PROBE_CMD='codex exec -m <model>' …      any headless CLI reading stdin
#   PROBE_REV=HEAD …                          probe the committed text instead of the tree
# A case names `skill: <name>` (rendered SKILL.md) or `agent: <name>` (rendered role file),
# or `listing: all` (name + description of every model-invocable rendered skill) / `listing: agents` (of every rendered role).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
usage() { echo "usage: tests/probes/run.sh [--dry-run] <case-id|all>   (PROBE_CMD overrides 'claude -p --model haiku')" >&2; exit 2; }
dry=0; [ "${1:-}" = "--dry-run" ] && { dry=1; shift; }
[ $# -eq 1 ] || usage
if [ "$1" = all ]; then cases=(tests/probes/cases/*.md); else cases=("tests/probes/cases/$1.md"); fi
cmd="${PROBE_CMD:-claude -p --model haiku}"
# One line per rendered skill, as the CLI lists it: name, description, then the
# when_to_use value when the skill still carries one (Claude lists both).
listing_line() {
  awk '/^---$/ { n++; if (n == 2) exit; next }
       n == 1 && /^disable-model-invocation: true/ { dmi = 1 }
       n == 1 && /^name: / { sub(/^name: /, ""); nm = $0 }
       n == 1 && /^description: / { sub(/^description: /, ""); ds = $0 }
       n == 1 && /^when_to_use: / { sub(/^when_to_use: /, ""); wu = $0 }
       END { if (nm != "" && !dmi) printf "- %s: %s%s\n", nm, ds, (wu != "" ? " — " wu : "") }'
}
listing_text() { # $1 = rendered skills dir
  local d f
  if [ -n "${PROBE_REV:-}" ]; then
    for d in $(git ls-tree --name-only "$PROBE_REV" "$1/"); do git show "$PROBE_REV:$d/SKILL.md" 2>/dev/null | listing_line; done
  else
    for f in "$1"/*/SKILL.md; do listing_line < "$f"; done
  fi
}
agents_text() { # $1 = rendered agents dir: one line per role file
  local f
  if [ -n "${PROBE_REV:-}" ]; then
    for f in $(git ls-tree --name-only "$PROBE_REV" "$1/"); do git show "$PROBE_REV:$f" 2>/dev/null | listing_line; done
  else
    for f in "$1"/*.md; do listing_line < "$f"; done
  fi
}
fail=0
for c in "${cases[@]}"; do
  [ -f "$c" ] || { echo "no such case: $c" >&2; exit 2; }
  skill=$(sed -n 's/^skill: *//p' "$c" | head -1)
  agent=$(sed -n 's/^agent: *//p' "$c" | head -1)
  core=$(sed -n 's/^core: *//p' "$c" | head -1)
  listing=$(sed -n 's/^listing: *//p' "$c" | head -1)
  with=$(sed -n 's/^with-skill: *//p' "$c" | head -1)   # extra skill names (space / comma separated) appended after the agent text
  preload=$(sed -n 's/^preload: *//p' "$c" | head -1)   # a role whose own preload carries the skill: nothing is inlined
  # Default Claude form: `claude -p --agent` runs the role as the MAIN thread, where `skills:` is not preloaded (measured, Task 25);
  # the preload applies to a dispatched sub-agent, so the default dispatches the role over the working-tree plugin (--plugin-dir).
  ccmd="$cmd"; wrap=0; [ -n "$preload" ] && [ -z "${PROBE_CMD:-}" ] && { ccmd="claude -p --plugin-dir plugins/rolepod --setting-sources project --allowedTools Agent --model haiku"; wrap=1; }
  if [ -n "$preload" ]; then path="role rolepod:$preload"; skill="preload $preload"; label=PRELOAD; text=
  elif [ "$listing" = agents ]; then path="plugins/rolepod/agents"; skill="role listing"; label=LISTING; text=$(agents_text "$path")   # name + description per rendered role
  elif [ -n "$listing" ]; then path="plugins/rolepod/skills"; skill="skill listing"; label=LISTING; text=$(listing_text "$path")   # name + description per rendered skill
  elif [ -n "$core" ]; then path="plugins/rolepod/hooks/always-on-core.md"; skill="always-on core"; label=CORE   # the rendered always-on core
  elif [ -n "$agent" ]; then path="plugins/rolepod/agents/$agent.md"; skill="agent $agent"; label=AGENT   # rendered role, fragments expanded
  else path="plugins/rolepod-codex/skills/$skill/SKILL.md"; label=SKILL; fi   # the standalone-rendered copy, includes expanded
  if [ -n "$preload" ]; then :
  elif [ -n "$listing" ]; then [ -n "$text" ] || { echo "empty listing for $path${PROBE_REV:+ at $PROBE_REV} (run make render / check PROBE_REV)" >&2; exit 2; }
  elif [ -n "${PROBE_REV:-}" ]; then text=$(git show "$PROBE_REV:$path") || { echo "missing $path at $PROBE_REV" >&2; exit 2; }
  else [ -f "$path" ] || { echo "missing rendered file: $path (run make render)" >&2; exit 2; }; text=$(cat "$path"); fi
  if [ -n "$preload" ]; then prompt=$(sed '1,/^---$/d' "$c")
    [ $wrap -eq 1 ] && prompt=$(printf "Dispatch the sub-agent rolepod:%s with the message between the <<< and >>> lines, verbatim. Wait for it, then print its reply verbatim, nothing else.\n<<<\n%s\n>>>" "$preload" "$prompt")
  else
  prompt=$( { sed '1,/^---$/d' "$c"; printf '\n--- %s (%s) ---\n' "$label" "$path"; printf '%s\n' "$text"; printf '\n--- END %s ---\nAnswer the task stated before the skill text, in its exact format, in English.\n' "$label"; } )
  fi
  if [ -n "$with" ]; then   # the with-skill bodies go after the agent text, before the closing line
    for w in ${with//,/ }; do wp="plugins/rolepod-codex/skills/$w/SKILL.md"; [ -f "$wp" ] || { echo "missing rendered file: $wp (run make render)" >&2; exit 2; }
      prompt+=$(printf '\n\n--- PRELOADED SKILL %s ---\n%s\n' "$w" "$(cat "$wp")"); done
  fi
  if [ $dry -eq 1 ]; then printf '%s\n' "$prompt"; continue; fi
  echo "── $(basename "$c" .md) → $skill"
  if ! answer=$(printf '%s' "$prompt" | $ccmd); then echo "  ✗ probe command failed: $ccmd"; fail=$((fail+1)); continue; fi
  printf '%s\n' "$answer" | sed 's/^/  │ /'
  while IFS= read -r rx; do
    [ -n "$rx" ] || continue
    if grep -Eq "$rx" <<<"$answer"; then echo "  ✓ expect: $rx"; else echo "  ✗ expect: $rx"; fail=$((fail+1)); fi
  done < <(sed -n 's/^expect: *//p' "$c")
  while IFS= read -r rx; do
    [ -n "$rx" ] || continue
    if grep -Eq "$rx" <<<"$answer"; then echo "  ✗ forbid: $rx"; fail=$((fail+1)); else echo "  ✓ forbid absent: $rx"; fi
  done < <(sed -n 's/^forbid: *//p' "$c")
done
[ $dry -eq 1 ] && exit 0
echo; [ $fail -eq 0 ] && { echo "probes: pass"; exit 0; }
echo "probes: $fail failure(s)"; exit 1
