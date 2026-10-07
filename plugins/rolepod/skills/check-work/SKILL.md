---
name: check-work
description: Use when a change is made and before claiming it is done; finish-work's merge gate needs the full-diff block; the user asks to verify, prove or test that a change works.
---

# Check Work

The done-claim helper: turns a claim ("done", "fixed", "works") into an evidence block — fresh proof, or an honest statement of what could not be proven.
A verify-only ask (the user asked only to verify, prove or test) ends at the evidence block.

**Iron Law:** no completion claim without proof run in this turn. A prior run counts only when its scope, inputs, environment and provenance still match; otherwise run it fresh.

## Skip when

- A no-op (comment, whitespace, docstring) with no behavior risk.
- The user said "just commit, I'll verify".
- You are building a task: proof, the base-tree rerun and the receipt are `implement-plan` Prove and Return; a bug fix's red proof is `tdd-flow` Watch it fail.

### 1. Name the proof

- Each acceptance criterion names its evidence: `<criterion> → <command + result line>`; none → `UNVERIFIED`, whatever else passed.
- A QA test-case table in play → each P1 ID maps, in the QA report, to a passing runner test, or to a manual run record when no tests were asked; a skipped or uncollected test counts as missing.

Done when: every criterion and P1 ID has a named command or observation; else Status `PARTIAL` / `UNVERIFIED`, naming the missing IDs.

### 2. Run it

- Run each named command; read the full output, exit code and failure count. Zero cases or all skipped → no test ran, never green.
- Evidence from the wrong surface or an inconclusive run is not a pass: mark it UNVERIFIED with the reason (a unit test for a UI claim, a local run for a staging claim, a flaky or skipped result).
- A `manifest.json` under `.rolepod/evidence/` (a sibling plugin ran) → `references/child-plugin-evidence.md`; no reference → keep only runs newer than your last relevant edit that name this target. Any kept `fail` fails the block.

Done when: every claim has a command and proof line from this turn, or a matching prior run cited.

### 3. Guard against a false green

- **Flip the assertion** — flip `==` to `!=` in your head; still passes → too weak, assert the exact value.
- **Wording trip wires** — "should pass", "looks right", "Done!" before the run → stop and run it first.
- **False equivalences** — linter clean ≠ build passes ≠ tests pass ≠ requirements met ≠ an agent's COMPLETED; "it compiled" is not runtime evidence.
- **Attribution** — "the user approved X" traces to a message stating X; a general "go ahead" authorizes nothing it did not name.

Done when: every assertion survives the flip and no claim rests on an equivalence.

### 4. State limitations, check F1-F5

Anything unproven (no test infra, no network, no browser) → four lines: Cannot verify / Reason / Risk if wrong / Suggested check. Never claim done over an unstated limitation.

- **F1 invented name** — every function, file and API used exists (Read / Grep).
- **F2 scope creep** — the diff is no wider than the request; cut the extra.
- **F3 cascading error** — the fix brought no new bug; run checks covering the fix and affected consumers. The full suite runs once per release, by the Lead.
- **F4 context loss** — every earlier constraint holds (re-read the request).
- **F5 tool misuse** — nothing destructive ran unannounced; review and announce it.

A failed check → fix it before declaring done.
Skip only when ALL hold: ≤5 lines · single file · zero logic-bearing (user-facing string text alone counts as zero) · NOT a high-risk path (= rigor tier R1, trivial edit).

Done when: everything unproven is listed with its risk, or Limitations reads "None", and F1-F5 hold.

### 5. Write the block

- Fill `templates/evidence-block.md` (no template → Change manifest, Evidence with the verified tree id and one command + proof line per check, Limitations, Verify status) in the receipt the brief names; never a second report.
- `finish-work` Pre-merge gate runs this once on the plan's full diff → the block goes to `<base checkout>/docs/rolepod/tasks/<plan file name without .md>/verify.md`, replacing the previous run. No plan → the block stays in chat.
- One file, no QA table, nothing to limit → `<command> → PASS: <specific proof>. Status: VERIFIED`. Examples → `examples/evidence-examples.md`.
- Verify status (`VERIFIED | PARTIAL | UNVERIFIED`) stays distinct from an owner's status (`COMPLETED | PARTIAL | BLOCKED`); PARTIAL and UNVERIFIED block merge.

Evidence log: append the line to `<git-root>/.rolepod/evidence/phase-log.jsonl` chained onto the next command you run anyway (`<cmd> && printf '…' >> phase-log.jsonl`), never as a standalone turn; skip silently outside a git repo.
Verify line: `{"ts":"<iso8601>","phase":"verify","verdict":"pass|partial|fail","evidence":"<command run>"}` — the verdict is the lowercase mapping of the Status word: VERIFIED → `pass`, PARTIAL → `partial`, UNVERIFIED → `fail`, and no other value is valid. Nothing follows the verify → chain it onto the verify command's own call (`<verify cmd> && printf '…pass…' >> … || printf '…fail…' >> …`).

Done when: the block carries one Status word and the verify line is appended.

## Next phase

- Verify-only ask → stop; the evidence block is the deliverable.
- Called from another skill → back to that skill's next step with the block's Status and proof lines.
- Run alone: VERIFIED → `finish-work`; a failing check → `debug-issue` with the failing command tail quoted.
- No other skill → stop and tell the user what was verified, each Limitations line and each failing command tail quoted, with the block's path.
