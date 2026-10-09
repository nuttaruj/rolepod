<!-- Fill these fields in the named task receipt; do not create another report. -->
<!-- Delete the <hints>. -->

## Decision brief
### Change manifest
<Files touched + a one-line what-changed each. The reader sees the diff scope.>
- `path` — <what changed>

### Evidence
Verified tree `<id>` = `scripts/docs-mode.sh tree` (no script → `git add -A && git write-tree`) — finish-work's Pre-merge gate cites this block (the plan's `verify.md`, else this session's chat) while `scripts/docs-mode.sh tree HEAD` equals this id and the tree is clean.
<One line per check. State the exact command and the SPECIFIC proof line —
 not "tests pass" but the assertion / count / status that proves it.>
- `<command>` — PASS: <specific proof, e.g. "12 examples, 0 failures" / "HTTP 200, body has id">
- `<command>` — PASS: <specific proof>

### Limitations
<Everything you could NOT verify. Empty only if you verified everything —
 then write "None" deliberately, do not omit the section.>
- Cannot verify: <what>
- Reason: <why — no infra / no network / no browser>
- Risk if wrong: <impact>
- Suggested check: <command or step the user can run>

## Verify status
<VERIFIED — every acceptance criterion proven.
 PARTIAL — some proven, limitations listed above.
 UNVERIFIED — could not prove the change works.>
VERIFIED | PARTIAL | UNVERIFIED
