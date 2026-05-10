#!/bin/bash
# Inject context-awareness reminder when transcript getting long.
# Reads stdin (Claude Code hook input). Silent if context fine.
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
TRANSCRIPT=$(echo "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null || echo "")

[ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] && exit 0

# Crude size proxy — file bytes. Real token count needs tokenizer.
BYTES=$(stat -f %z "$TRANSCRIPT" 2>/dev/null || stat -c %s "$TRANSCRIPT" 2>/dev/null || echo 0)

# Thresholds (tuned to typical session sizes)
WARN=2000000   # ~2MB ≈ ~50% of 200k context
HOT=4000000    # ~4MB ≈ near full

if [ "$BYTES" -ge "$HOT" ]; then
  cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"⚠️ **Context HOT** — transcript >4MB. Consider `/clear` (unrelated tasks) or `/compact <focus>` (preserve current work). See session-management.md."}}
EOF
elif [ "$BYTES" -ge "$WARN" ]; then
  cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"📊 Context filling — consider delegating to subagent (isolated context) or `/btw` for side questions. See session-management.md."}}
EOF
else
  echo '{}'
fi

exit 0
