#!/usr/bin/env bash
# agent-sync.sh — Codex-only SessionStart hook (rolepod).
#
# WHY: the Codex plugin manifest has no `agents` component — custom agents
# load only from ~/.codex/agents/ (global) and .codex/agents/ (project). So
# `codex plugin marketplace upgrade` refreshes the plugin's hooks + skills but
# never the role agents nor the rolepod block in ~/.codex/AGENTS.md; those
# used to need a fresh `install.sh` run. This hook closes the gap from inside
# the plugin cache: the bundled agents/rolepod-*.toml + agents/AGENTS.rolepod.md
# (both rendered by build/render.sh) are synced into $CODEX_HOME whenever the
# plugin version differs from the stamp written on the last sync.
#
# GUARANTEES
#   - Only rolepod-*.toml files are written or pruned; user agents untouched.
#   - ~/.codex/AGENTS.md: ONLY the <!-- rolepod:start --> … <!-- rolepod:end -->
#     block is replaced (same markers install.sh uses); everything outside it
#     is preserved byte-exact. No block yet → append one. File missing →
#     create block-only.
#   - Version-guarded: no-op while the stamp matches the plugin version;
#     content-diffed: a file is rewritten only when it differs.
#   - Fail-open: every failure path exits 0 silently — a broken sync never
#     blocks a session. Off switch: ROLEPOD_AGENT_SYNC_OFF=1.
# OUTPUT: SessionStart additionalContext one-liner only when something changed.
set -u
cat >/dev/null 2>&1 || true            # drain the hook JSON on stdin (unused)
[ -n "${ROLEPOD_AGENT_SYNC_OFF:-}" ] && exit 0

PLUGIN_ROOT="${PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}"
SRC="$PLUGIN_ROOT/agents"
MANIFEST="$PLUGIN_ROOT/.codex-plugin/plugin.json"
[ -d "$SRC" ] && [ -f "$MANIFEST" ] || exit 0

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
DEST="$CODEX_HOME/agents"
STAMP="$DEST/.rolepod-agents-version"
BLOCK_SRC="$SRC/AGENTS.rolepod.md"
TARGET="$CODEX_HOME/AGENTS.md"
START="<!-- rolepod:start -->"
END="<!-- rolepod:end -->"

ver=$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$MANIFEST" | head -1)
[ -n "$ver" ] || exit 0
if [ -f "$STAMP" ] && [ "$(cat "$STAMP" 2>/dev/null)" = "$ver" ]; then exit 0; fi
mkdir -p "$DEST" 2>/dev/null || exit 0

# One syncer at a time (two sessions launching together). A lock older than
# two minutes is a crash leftover — take it over rather than stay silent forever.
LOCK="$DEST/.rolepod-sync.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +2 2>/dev/null)" ]; then
    rmdir "$LOCK" 2>/dev/null; mkdir "$LOCK" 2>/dev/null || exit 0
  else
    exit 0
  fi
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

# ── Role agents: copy changed, prune retired (rolepod- prefix only) ──────────
agents=0; pruned=0; block=""
for f in "$SRC"/rolepod-*.toml; do
  [ -f "$f" ] || continue
  d="$DEST/$(basename "$f")"
  cmp -s "$f" "$d" && continue
  cp "$f" "$d" 2>/dev/null && agents=$((agents+1))
done
for d in "$DEST"/rolepod-*.toml; do
  [ -f "$d" ] || continue
  [ -f "$SRC/$(basename "$d")" ] && continue
  rm -f "$d" 2>/dev/null && pruned=$((pruned+1))
done

# ── AGENTS.md managed block: replace ours, keep everything else ─────────────
if [ -f "$BLOCK_SRC" ]; then
  cur=$(awk -v s="$START" -v e="$END" '$0==s{i=1;next} i&&$0==e{exit} i{print}' "$TARGET" 2>/dev/null)
  new=$(cat "$BLOCK_SRC")
  if [ "$cur" != "$new" ]; then
    tmp=$(mktemp "${TMPDIR:-/tmp}/rolepod-agents-md.XXXXXX" 2>/dev/null) || tmp=""
    if [ -n "$tmp" ]; then
      if [ -s "$TARGET" ]; then
        if grep -qF "$START" "$TARGET" && grep -qF "$END" "$TARGET"; then
          # strip the existing block; user content around it survives
          awk -v s="$START" -v e="$END" '$0==s{i=1;next} i{if($0==e)i=0;next} {print}' "$TARGET" > "$tmp"
        else
          cat "$TARGET" > "$tmp"
        fi
        # trim trailing blank lines, then one separator before our block
        awk '{l[NR]=$0} END{n=NR; while(n>0 && l[n] ~ /^[[:space:]]*$/) n--; for(i=1;i<=n;i++) print l[i]}' "$tmp" > "$tmp.2" \
          && mv "$tmp.2" "$tmp"
        [ -s "$tmp" ] && printf '\n' >> "$tmp"
      fi
      { printf '%s\n' "$START"; cat "$BLOCK_SRC"; printf '\n%s\n' "$END"; } >> "$tmp"
      mkdir -p "$CODEX_HOME" 2>/dev/null
      # cat-over (not mv) keeps the target's inode, perms, and any symlink
      cat "$tmp" > "$TARGET" 2>/dev/null && block="AGENTS.md rolepod block refreshed"
      rm -f "$tmp" "$tmp.2" 2>/dev/null
    fi
  fi
fi

printf '%s\n' "$ver" > "$STAMP" 2>/dev/null

if [ "$agents" -gt 0 ] || [ "$pruned" -gt 0 ] || [ -n "$block" ]; then
  msg="rolepod: synced to plugin v$ver — $agents role agent(s) updated"
  [ "$pruned" -gt 0 ] && msg="$msg, $pruned retired"
  [ -n "$block" ] && msg="$msg, ~/.codex/$(basename "$TARGET") rolepod block refreshed (content outside the block untouched)"
  msg="$msg. Codex reads agents + AGENTS.md at session start — fully live from the next session."
  ROLEPOD_HOOK_CTX="$msg" python3 -c '
import json, os
print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": os.environ.get("ROLEPOD_HOOK_CTX", "")}}))
' 2>/dev/null || echo '{}'
fi
exit 0
