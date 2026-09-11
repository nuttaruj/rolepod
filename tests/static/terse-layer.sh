#!/usr/bin/env bash
# Static test — the opt-in terse-output layer.
#
# The one invariant that matters: a user who has NOT created the flag pays
# nothing. No flag → no bytes, on every target. With the flag, the payload is
# the shipped terse-core.md verbatim plus a banner naming the flag, and it
# stays inside its own budget — separate from the always-on 5120 B budget,
# which this layer must never touch.
#
# Run directly: bash tests/static/terse-layer.sh
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Exercise the SHIPPED artifact — the rendered plugin tree, not the .md.tmpl
# source (whose {{INCLUDE}} directives are unresolved).
HOOK="$REPO_DIR/plugins/rolepod/hooks/terse-loader.sh"
CORE="$REPO_DIR/plugins/rolepod/hooks/terse-core.md"
HOOKS_JSON="$REPO_DIR/adapters/claude/hooks.json"
BUDGET=2048

fail=0
pass() { echo "  ✓ $1"; }
bad()  { echo "  ✗ $1"; fail=$((fail + 1)); }

# Isolated config dir so the runner's own opt-in cannot decide the result.
TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT
FLAG="$TMP_HOME/.rolepod-terse"

echo "terse-layer:"

# 1. Shipped artifacts present.
[ -f "$HOOK" ] && pass "plugin terse-loader.sh exists" || bad "plugin terse-loader.sh missing"
[ -s "$CORE" ] && pass "plugin terse-core.md is non-empty" || bad "plugin terse-core.md missing or empty"

# 2. No flag → no output at all. Not an empty JSON object: nothing.
if [ -f "$HOOK" ]; then
  OUT=$(echo '{}' | CLAUDE_CONFIG_DIR="$TMP_HOME" bash "$HOOK" 2>/dev/null; echo "rc=$?")
  if [ "$OUT" = "rc=0" ]; then
    pass "no flag → zero bytes, exit 0 (opt-out costs nothing)"
  else
    bad "no flag → expected zero bytes and exit 0, got: $OUT"
  fi
fi

# 3. Flag → valid SessionStart JSON carrying the core verbatim.
if [ -f "$HOOK" ] && [ -f "$CORE" ]; then
  : > "$FLAG"
  OUT=$(echo '{}' | CLAUDE_CONFIG_DIR="$TMP_HOME" bash "$HOOK" 2>/dev/null || echo "")
  if printf '%s' "$OUT" | python3 -I -c '
import sys, json
core = open(sys.argv[1], encoding="utf-8").read()
d = json.load(sys.stdin)
o = d["hookSpecificOutput"]
assert o["hookEventName"] == "SessionStart", "wrong hookEventName"
ctx = o["additionalContext"]
assert ctx.startswith("TERSE OUTPUT ACTIVE (level: default)"), "banner missing or wrong level"
assert sys.argv[2] in ctx, "banner does not name the flag file"
assert core in ctx, "core content not carried verbatim"
' "$CORE" "$FLAG" 2>/dev/null; then
    pass "flag → SessionStart JSON, banner names the flag, core verbatim"
  else
    bad "flag → did not emit the expected SessionStart payload"
  fi

  # 4. Budget — its own, never the always-on 5120 B.
  SIZE=$(printf '%s' "$OUT" | python3 -I -c '
import sys, json
sys.stdout.write(str(len(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"].encode("utf-8"))))
' 2>/dev/null || echo "")
  if [ -n "$SIZE" ] && [ "$SIZE" -le "$BUDGET" ]; then
    pass "payload ${SIZE}B within ${BUDGET}B budget"
  else
    bad "payload ${SIZE:-unknown}B exceeds ${BUDGET}B budget"
  fi

  # 5. Level word in the flag selects the shape; junk reads as default.
  echo ultra > "$FLAG"
  OUT=$(echo '{}' | CLAUDE_CONFIG_DIR="$TMP_HOME" bash "$HOOK" 2>/dev/null || echo "")
  printf '%s' "$OUT" | grep -q 'TERSE OUTPUT ACTIVE (level: ultra)' \
    && pass "flag containing 'ultra' selects the ultra level" \
    || bad "flag containing 'ultra' did not select the ultra level"

  echo "wharrgarbl" > "$FLAG"
  OUT=$(echo '{}' | CLAUDE_CONFIG_DIR="$TMP_HOME" bash "$HOOK" 2>/dev/null || echo "")
  printf '%s' "$OUT" | grep -q 'TERSE OUTPUT ACTIVE (level: default)' \
    && pass "unrecognised flag content falls back to default" \
    || bad "unrecognised flag content did not fall back to default"
fi

# 6. Always-on stays independent — the terse loader is its own registration,
#    so a failure in one can never take the other down.
if [ -f "$HOOKS_JSON" ]; then
  python3 -I -c '
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
cmds = [h["command"] for block in d["hooks"]["SessionStart"] for h in block["hooks"]]
assert any("terse-loader.sh" in c for c in cmds), "terse-loader.sh not registered on SessionStart"
assert any("always-on-loader.sh" in c for c in cmds), "always-on-loader.sh registration lost"
' "$HOOKS_JSON" 2>/dev/null \
    && pass "SessionStart wires terse-loader alongside always-on-loader" \
    || bad "SessionStart registration missing or malformed"
fi

# 7. Every target ships a way in. Hook targets ship the core file; the
#    doc targets ship the pointer that names it; Cursor ships the rule.
for artifact in \
  "plugins/rolepod/hooks/terse-core.md" \
  "plugins/rolepod-codex/hooks/terse-core.md" \
  "plugins/rolepod-cursor/rules/terse.mdc"
do
  [ -s "$REPO_DIR/$artifact" ] && pass "ships $artifact" || bad "missing $artifact"
done

if [ -s "$REPO_DIR/plugins/rolepod-cursor/rules/terse.mdc" ]; then
  grep -q '^alwaysApply: false' "$REPO_DIR/plugins/rolepod-cursor/rules/terse.mdc" \
    && pass "cursor rule is opt-in (alwaysApply: false)" \
    || bad "cursor terse rule must not be alwaysApply: true"
fi

# 8. Gemini's session-start.sh folds the same opt-in check inline (no separate
#    registration to isolate it) — build a fixture next to a copy of the
#    script, since the rendered gemini tree is a gitignored build artifact.
GEMINI_HOOK="$REPO_DIR/adapters/gemini/hooks/session-start.sh"
if [ -f "$GEMINI_HOOK" ] && [ -f "$CORE" ]; then
  GTMP="$(mktemp -d)"
  mkdir -p "$GTMP/hooks"
  cp "$GEMINI_HOOK" "$GTMP/hooks/session-start.sh"
  cp "$CORE" "$GTMP/hooks/terse-core.md"
  GFLAGDIR="$(mktemp -d)"
  : > "$GFLAGDIR/.rolepod-terse"

  # 8a. Baseline — flag set, core readable: still emits valid JSON carrying
  #     the git-context payload, with the terse core folded in.
  OUT=$(CLAUDE_CONFIG_DIR="$GFLAGDIR" bash "$GTMP/hooks/session-start.sh" 2>/dev/null)
  RC=$?
  if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | python3 -I -c '
import sys, json
d = json.load(sys.stdin)
ctx = d["hookSpecificOutput"]["additionalContext"]
assert "TERSE OUTPUT ACTIVE" in ctx, "terse banner missing from gemini payload"
' 2>/dev/null; then
    pass "gemini session-start.sh: flag + readable core → valid JSON with terse banner"
  else
    bad "gemini session-start.sh: flag + readable core → expected valid JSON, got rc=$RC out=${OUT:0:120}"
  fi

  # 8b. terse-core.md exists but is UNREADABLE (permission-denied, not
  #     missing). session-start.sh is one monolithic `set -euo pipefail`
  #     script — unlike the Claude loader, the terse block is not a separate
  #     hook registration, so a failure here must not cost the rest of the
  #     payload (git context, gate reminders, cross-family prompt). It must
  #     still emit the single required JSON object per the hook contract
  #     documented at the top of the script ("stdout = single JSON object").
  #     A weaker check (valid JSON alone) would still pass a broken "fix"
  #     that swallows the error by emitting an empty payload — assert the
  #     rest of the hook (git context + gates) survives the failed read,
  #     and that no terse banner leaks through with an empty body.
  chmod 000 "$GTMP/hooks/terse-core.md"
  CLAUDE_CONFIG_DIR="$GFLAGDIR" bash "$GTMP/hooks/session-start.sh" >"$GTMP/out.json" 2>/dev/null
  RC=$?
  chmod 644 "$GTMP/hooks/terse-core.md"
  if [ "$RC" -eq 0 ] && python3 -I -c '
import sys, json
d = json.load(open(sys.argv[1]))
ctx = d["hookSpecificOutput"]["additionalContext"]
assert "--- git context ---" in ctx, "git context lost when terse-core.md read failed"
assert "rolepod gates" in ctx, "gates reminder lost when terse-core.md read failed"
assert "TERSE OUTPUT ACTIVE" not in ctx, "terse banner must not appear with a failed read"
' "$GTMP/out.json" 2>/dev/null; then
    pass "gemini session-start.sh: unreadable terse-core.md → git context + gates survive, no bare banner"
  else
    bad "gemini session-start.sh: unreadable terse-core.md → rc=$RC (expected rc=0, valid JSON, git context + gates intact, no terse banner; the whole hook payload must not be lost because the opt-in terse block failed to read its own file)"
  fi

  rm -rf "$GTMP" "$GFLAGDIR"
fi

if [ $fail -eq 0 ]; then echo "  all terse-layer checks passed"; else exit 1; fi
