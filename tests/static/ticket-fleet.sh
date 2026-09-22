#!/bin/bash
# Static test — scripts/ticket-fleet.js (spec: lead-cost-no-pause-2026-09-22
# Task 5). Parses; `meta` is a pure literal; every agent() call on a
# writing (Build/Fix) or reviewing (Review) stage is pinned to a rolepod
# role; no strong (`opus`) model literal anywhere — the fleet-tier hook
# never lets a fan-out call keep one, and the review stage's own tier comes
# from the reviewer role's frontmatter, not a script pin; no Date.now() /
# Math.random() / bare new Date() — they would break a resumed run.
set -uo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_DIR/scripts/ticket-fleet.js"
fail=0

if [ ! -f "$SCRIPT" ]; then
  echo "  ✗ $SCRIPT: No such file"
  echo "ticket-fleet: 1 failure(s)"
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "  ✗ node not on PATH — cannot check $SCRIPT"
  echo "ticket-fleet: 1 failure(s)"
  exit 1
fi

ERR="$(mktemp)"; trap 'rm -f "$ERR"' EXIT
if node --check "$SCRIPT" 2>"$ERR"; then
  echo "  ✓ node --check parses $SCRIPT"
else
  echo "  ✗ node --check failed:"
  sed 's/^/      /' "$ERR"
  fail=$((fail+1))
fi

CHECK="$(mktemp -t ticket-fleet-static-XXXXXX.js)"
cat > "$CHECK" <<'JS'
const fs = require('fs')
const path = process.argv[2]
const src = fs.readFileSync(path, 'utf8')
let fail = 0
const bad = (m) => { console.log('  ✗ ' + m); fail++ }
const ok = (m) => { console.log('  ✓ ' + m) }

// meta is a pure literal — an object literal that evaluates in isolation,
// with no reference to any outer variable, call, or spread.
const m = src.match(/export const meta\s*=\s*(\{[\s\S]*?\n\})\n/)
if (!m) {
  bad('no "export const meta = {...}\\n}" literal found')
} else {
  let meta = null
  try {
    // eslint-disable-next-line no-eval
    meta = eval('(' + m[1] + ')')
  } catch (e) {
    bad('meta is not a pure literal: ' + e.message)
  }
  if (meta) {
    if (typeof meta.name === 'string' && typeof meta.description === 'string') {
      ok('meta is a pure literal with name + description')
    } else {
      bad('meta literal is missing name/description')
    }
  }
}

// REVIEWER_SCHEMA.report / .blocking items / VERIFY_SCHEMA.tail all carry a
// maxLength — the live run (wf_3a5a836e-cbc) returned each reviewer's full
// 1.5-2.5 KB report text instead of its path, landing in the Lead's
// context (the exact cost this plan removes). A schema literal is read the
// same way meta is: eval'd in isolation, never re-derived by string-scanning.
function schemaLiteral(name) {
  const sm = src.match(new RegExp('const ' + name + '\\s*=\\s*(\\{[\\s\\S]*?\\n\\})\\n'))
  if (!sm) return null
  try {
    // eslint-disable-next-line no-eval
    return eval('(' + sm[1] + ')')
  } catch (e) {
    return null
  }
}
const reviewerSchema = schemaLiteral('REVIEWER_SCHEMA')
if (!reviewerSchema) {
  bad('REVIEWER_SCHEMA not found as a pure literal')
} else {
  const reportCap = reviewerSchema.properties && reviewerSchema.properties.report
  const blockingCap = reviewerSchema.properties && reviewerSchema.properties.blocking &&
    reviewerSchema.properties.blocking.items
  if (reportCap && typeof reportCap.maxLength === 'number' && reportCap.maxLength <= 300) {
    ok('REVIEWER_SCHEMA.report caps maxLength <= 300 — a path, never report text')
  } else {
    bad('REVIEWER_SCHEMA.report has no maxLength <= 300')
  }
  if (blockingCap && typeof blockingCap.maxLength === 'number' && blockingCap.maxLength <= 120) {
    ok('REVIEWER_SCHEMA.blocking items cap maxLength <= 120 — one line, not a full finding')
  } else {
    bad('REVIEWER_SCHEMA.blocking items have no maxLength <= 120')
  }
}

// no verifier stage: the fleet no longer re-runs the brief's Command/Proof
// itself — 'rolepod-ticket integrate' is the sole re-verifier before commit.
if (/VERIFY_SCHEMA/.test(src)) {
  bad('VERIFY_SCHEMA still present — the verifier stage should be gone')
} else {
  ok('no VERIFY_SCHEMA — no scripted verifier stage')
}
if (/phase\s*:\s*['"]Verify['"]/i.test(src) || /['"]verifier['"]/i.test(src)) {
  bad("a 'Verify'/'verifier' stage string is still present")
} else {
  ok("no 'Verify'/'verifier' stage string")
}

// the owner and fix prompts must tell the owner to loop on the brief's
// ## Check and run ## Command once itself, since nothing downstream in the
// fleet re-runs it for them anymore.
const ownerPromptSrc = (src.match(/function ownerPrompt[\s\S]*?\n\}/) || [''])[0]
const fixPromptSrc = (src.match(/function fixPrompt[\s\S]*?\n\}/) || [''])[0]
if (/## Check/.test(ownerPromptSrc)) {
  ok('ownerPrompt tells the owner to loop on the brief\'s ## Check')
} else {
  bad('ownerPrompt has no "## Check" instruction')
}
if (/## Check/.test(fixPromptSrc)) {
  ok('fixPrompt tells the owner to loop on the brief\'s ## Check')
} else {
  bad('fixPrompt has no "## Check" instruction')
}

// no Date.now() / Math.random() / bare new Date() — they break workflow resume.
if (/Date\.now\s*\(|Math\.random\s*\(|new Date\s*\(\s*\)/.test(src)) {
  bad('Date.now()/Math.random()/new Date() found — breaks workflow resume')
} else {
  ok('no Date.now()/Math.random()/new Date()')
}

// no strong (opus) model literal anywhere in the script.
if (/model\s*:\s*['"]opus['"]/.test(src)) {
  bad("model: 'opus' literal found — strong belongs to the reviewer role's own tier, never a script pin")
} else {
  ok("no model: 'opus' literal on any call")
}

// the fleet-tier gate's escape hatch (docs/rolepod/handoffs/ticket-fleet-
// probe-2026-09-22.md #5) — required even though most of this script's
// tiering is self-evident (dynamic agentType + literal balanced/cheap
// models), belt and braces against a re-shuffle that loses one.
if (/\/\/\s*tier-reason:/.test(src)) {
  ok('// tier-reason: comment present')
} else {
  bad('no "// tier-reason:" comment — the fleet-tier gate wants one')
}

// Every agent( call on a writing (Build/Fix) or reviewing (Review) stage
// carries an agentType tied to a rolepod role. Dynamic values MUST be
// template literals (`rolepod:${x}`) — a `'rolepod:' + x` concatenation is
// invisible to the fleet-tier hook's per-call pin check (it resolves only
// the closed 'rolepod:' portion and never sees the rest), so that call
// reads as unpinned on a fan-out and risks a bare-fan-out deny under a
// strong/unknown Lead. No scripted Verify stage exists anymore (§ above) —
// every remaining agent( call is Build/Fix or Review and must be pinned.
const WRITE_RX = /(implement|build|fix|integrat|migrat|refactor|patch|scaffold|write)/i
const calls = []
let i = 0
while ((i = src.indexOf('agent(', i)) !== -1) {
  let depth = 0
  let j = i + 'agent('.length - 1
  const start = i
  for (; j < src.length; j++) {
    if (src[j] === '(') depth++
    else if (src[j] === ')') { depth--; if (depth === 0) break }
  }
  calls.push(src.slice(start, j + 1))
  i = j + 1
}
const uncovered = []
for (const call of calls) {
  const pm = call.match(/phase\s*:\s*['"]([^'"]+)['"]/)
  const stage = pm ? pm[1] : ''
  const isWrite = WRITE_RX.test(stage)
  const isReview = stage.toLowerCase() === 'review'
  if ((isWrite || isReview) && !/agentType\s*:\s*[`'"]rolepod:/.test(call)) {
    uncovered.push(stage || '(no phase)')
  }
}
if (calls.length === 0) {
  bad('no agent( calls found')
} else if (uncovered.length === 0) {
  ok('every agent() call on a Build/Fix/Review stage carries agentType tied to a rolepod role')
} else {
  bad('agent() call(s) with no rolepod agentType on stage(s): ' + uncovered.join(', '))
}

process.exit(fail)
JS
OUT=$(node "$CHECK" "$SCRIPT" 2>&1); RC=$?
rm -f "$CHECK"
printf '%s\n' "$OUT"
fail=$((fail+RC))

if [ "$fail" -eq 0 ]; then echo "ticket-fleet: pass"; exit 0; fi
echo "ticket-fleet: $fail failure(s)"; exit "$fail"
