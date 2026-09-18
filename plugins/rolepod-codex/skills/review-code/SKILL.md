---
name: review-code
description: Use before merging or shipping — review code with risk-appropriate adversarial pressure across correctness, security, performance, UI, and architecture. Pick reviewer by risk profile. Phase = Review.
when_to_use: when a change is ready to ship and needs a second-pass read for correctness, regressions, security, performance, architecture, or UI compliance before merge
tier: 1
phase: review
---

# Review Code

Risk-appropriate review pressure on a finished change: multi-axis read, adversarial review for high-risk diffs.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER merge code on a high-risk surface (auth, billing, payments, credits, migration, data deletion, secrets, tokens, crypto, permissions, security) without an adversarial fresh-context review.
2. NEVER let the author — or, for the adversarial pass, the author's own model — be the final reviewer of their own change.
   - The external adversarial review runs in a **CLI** different from the Lead's, on that CLI's own default model (same vendor is fine).
   - The vertical fallback (same CLI, stronger tier) and an inline advisor (inside the author's context) never satisfy it; both only raise the Lead floor, recorded as a limitation.
3. NEVER skip review because "tests pass". Tests prove the assertion, not the design.
4. Findings before fixes — the whole round's findings, never the first report's. Severity-ordered list; no silent rewrite.
5. The author MUST verify findings against the codebase before implementing. No performative agreement, no blind implementation; clarify before a partial implementation.
</EXTREMELY-IMPORTANT>

## Skip when

- Pure docs / typo / whitespace · the user explicitly accepts the change unreviewed · R1: ≤5 lines, single file, zero logic (user-facing string text alone counts as zero off high-risk paths), NOT high-risk.

## Boundary

Owns: risk-appropriate second-pass review — finding discovery, severity ordering, the adversarial read.

Does not own: silent implementation fixes · the merge / PR decision · re-running the full suite unless a finding needs it.

Hand off:
- The user asked only for a review — no fix, no ship requested → the report is the deliverable; stop here. Otherwise:
  - Findings need fixes → `implement-plan` or `debug-issue`. Fixes landed → `check-work`.
  - No blockers, plan has unchecked tasks → `implement-plan` (Ship asks once per plan). Plan exhausted → `finish-work`.

## Workflow

Inputs to gather:
- **The diff** = the shipped task or its ship group, never the whole plan: committed branch → `<base>...HEAD`; uncommitted → `git diff HEAD` (staged + unstaged). `--cached` alone is a slice; the runner refuses one whose files carry uncovered tree edits (`--partial-ok` only on request).
- Past ~15 files / ~800 lines it is two concerns — split before dispatch; reviewers read what fits.
- The spec / plan / acceptance criteria · the touched files end-to-end · the risk profile (high-risk surface? new dep? schema change?) · which reviewers are available.

### 1. Pick reviewer by risk

| Risk profile | Reviewer |
|--------------|----------|
| High-risk surface (the Iron Rule 1 list) | `security-engineer` + adversarial fresh-context |
| Correctness / spec compliance | `universal-reviewer` (spec axis) |
| User-visible behaviour (UI / E2E / API contract) | `qa-tester` (E2E) |
| Performance regression risk | `performance-engineer` |
| UI / interaction / a11y | `ui-ux-designer` |
| Architecture / cross-module | `system-architect` |
| Generic quality / DRY / smell | `universal-reviewer` |

Brief every reviewer with: diff + spec + acceptance criteria + risk profile + the claimed behaviors to trace end-to-end + which roles already ran.
rolepod-brain: add `brain_seed(task, agent: <reviewer id>)` verbatim; no tool → skip.

**By rigor tier** (R1 trivial edit · R2 one file + test · R3 multi-file · R4 high-risk):
- **R1** → no review, no re-read turn; the edit tool's echo is the evidence. A docs-only diff is R1 at any size — no reviewer, internal or external; its own check (link check / static lint) is the verify.
- **R2** → ONE read-only `universal-reviewer` pass on the diff (two axes: spec + standards; the author never reviews own logic); a matched row (perf / UI / arch) → that role instead. The writer's unit tests are the floor.
- **R3** → the row match, internal only — the pool is an R4 instrument (the user asks → one pass). A high-risk path anywhere in the diff under review (the task or its ship group) tiers that diff R4; the commission's tier is the max over its tasks and governs Define / Plan only — a diff reviewed at its tier is never reviewed again at ship.
- **R4** → the full adversarial floor, never less — ONE strong pass: the external when the pool is usable (dispatched by the task owner), else the internal strong. The router's comment/blank-only carve-out (1 file, ≤5 lines, zero logic) lands here as R2 + ONE internal strong reviewer, no external — the pool reviews code, never a comment / doc / config / rename diff.

**Satellite-first strong pass.** A usable cross-family external IS the R4 strong adversarial pass: `rolepod-cross-family --kind review --brief <brief> --attach <diff> --detach` — read-only, anchored by the runner.

**Detach by default.** The runner returns a job id and runs the chain (first member → fallbacks) with each member's budget (mechanics: `references/external-review-routing.md`).
- Dispatch the internal reviewer and, on money / auth, the internal strong reviewer in the same breath; then keep working OUTSIDE the diff or end the turn.
- `rolepod-cross-family --collect <job-id>` waits up to the budget, in the foreground.

**Internal strong reviewer** (`security-engineer` / `universal-reviewer`) runs when any holds:
- (a) cross-family is off, or the runner reports no usable member (every member failed / pool empty — logged);
- (b) **the round-3 breaker** (§5) — a BLOCKER still open after 3 rounds on ONE tree (never counted across tickets) → the internal strong reviews the class, ONE round beside the external; never both on round 1, money / auth included;
- (c) **the external came back weak** — family `unknown`, no TRACED finding, or a verdict with no claims walked;
- (d) an apex trigger holds — the apex rung, external first, internal only when (c);
- (e) re-reading fixes in the §5 loop.

It runs at STRONG class even under a balanced Lead: never pass a balanced model on it (a hooked CLI lifts a model-less call; elsewhere pass an explicit strong-class override). `qa-tester` (E2E / UI) is never the strong pass, never counted as one.

**Apex escalation.** Strong is the R4 default ("done right per the existing pattern?"); apex — the strongest model the CLI exposes — asks "is the pattern itself right?". Escalate only on:
1. irreversible with no rollback — destructive migration, key rotation, live money movement;
2. novel design with no pattern to diff against;
3. deep cross-system reasoning — races on financial invariants, distributed consistency;
4. the previous strong round missed blockers;
5. the user asks.

No trigger → strong stands; a CLI whose strong pin IS its ceiling collapses apex into strong. A costlier rung is a cost decision to surface first; a ceiling below frontier-class still gets the full review, depth cap recorded as a LIMITATION. The dispatch line's `override` records the rung sent.

**One review round.** Every reviewer that fires is dispatched in ONE message on the same frozen diff; that dispatch plus the Lead's own read is one round, and it ends when the LAST member returns (`--collect` for a detached job).
- Until then the diff is frozen: no edit to a file it touches, no `git stash / reset / checkout / add / commit` (a red-proof revert runs in a throwaway worktree) — reviewers read the live tree, so one early fix voids every in-flight verdict.

Reviews merge severity-ordered, deduped by file:line + root cause (the Lead's findings included); §6 starts on the merged list; only the §5 loop is serial. Vocabulary map: CRITICAL/HIGH → BLOCKER, WARNING/MEDIUM → MAJOR, SUGGESTION/LOW → MINOR.

**External adversarial review — a different CLI, never the Lead's own.**
- The pool is the user's choice and **opt-in**: `<git-root>/.rolepod/cross-family`, then `~/.rolepod/cross-family` (`rolepod-cross-family --setup`), minus the Lead's own CLI; no file or `none` = off, never turned on unasked.
- An externally implemented ship group (`--kind implement`) is reviewed by a DIFFERENT member — the runner skips the implementer while its ticket is uncommitted; a user-lifted risky scope (`risky:lifted`) → the external pass by a different member.
- Enabled + R4 + logic-bearing code diff + usable member → routing to it is mandatory; R1-R3, and any doc / comment / config / rename-only diff, stay internal unless the user asks.
- The writer's unit tests + the Lead's own read are the floor and backstop any reviewer that is missing or fails.
- **An empty or partial return is a failed reviewer, never a clean pass** — a lens answering `""`, a one-sentence result, a turn-limit notice: resume it or re-dispatch on a narrower brief; until it reports the round is open and the report records a LIMITATION.
- No dispatch possible at all (user forbade agents / no subagent support) → the Lead's cold self-review stands in as a recorded LIMITATION — surface the conflict, never self-set a bypass.
- On a CLI without hooks this section is the gate.

### 2. Multi-axis read

- **Intent** — the goal in one sentence; is there a smaller way, or should the change exist at all? Surface before the line read.
- **Trace** — the diff is the entry point, not the scope. For each claimed behavior walk the real path (entry → call sites → branches → state → exit) through the seams into unchanged code; every surprise on the walk is findings signal. Bound the walk to the change's claims and seams (untouched code is a Question, not a BLOCKER); code-intel callers / impact when connected.
- **Correctness** — logic vs spec, edge cases, off-by-one, null / undefined / empty.
- **Security** — input validation, auth check, secret handling, SSRF, injection, token leak in logs.
- **Performance** — N+1, blocking calls, unbounded loops, big payloads, missing index.
- **Architecture** — matches existing patterns? source-of-truth violations? new abstraction with one user? hand-rolled logic the stdlib or platform already ships (native input, CSS, DB constraint, `Intl.*`)? A simplification finding names the concrete replacement. A declared module boundary map (CLAUDE.md / ADR) → every NEW cross-module import checked; a dependency-direction reversal or undeclared crossing is a BLOCKER.
- **Conventions** — written project rules (CLAUDE.md, lint / formatter config): a written rule the diff breaks is a MAJOR with the rule quoted; an unwritten preference is a MINOR at most. Cite the CLAUDE.md line, never restate it.
- **UI** — a11y, hierarchy, consistency, platform conventions.
- **Tests** — assertion strength, mocks at the right boundary, race coverage for concurrent code. A diff that *modifies an existing test* on the way to green is a finding until justified (loosened assertion, raised tolerance, deleted case, skip / only, absorbed snapshot). N call-site tests of one shared rule → one at the owner plus a smoke each. A new test naming a calendar date or reading the real clock → derive from one frozen now.

### 3. Adversarial mode for high risk

Fresh context. The reviewer reads only the artifact + acceptance criteria, tries to make the change fail, and looks for what is missing as hard as what is present.

### 4. Report findings, severity-ordered

Fill `templates/review-report.md`. Each finding: file:line, the issue, why it matters, a fix direction — never a silent rewrite.
- Label evidence **TRACED** (path walked; holds or fails at a named step) or **SUSPECTED** (pattern-level; the author verifies per §6).
- Label provenance **INTRODUCED** (this diff caused it), **EXPOSED** (pre-existing, on a path this diff changes) or **ADJACENT** (pre-existing, path untouched; listed once, never drives the verdict).
- A clean review is never a bare APPROVED: the Claims-traced section states what was walked and which axes ran.
- The full report goes to `.rolepod/evidence/review/<task>-<role>.md`; the reviewer returns ≤12 lines + verdict (a relayed message truncates).

### 5. Fix-verify loop

Round 2+: `rolepod-cross-family --kind review --brief <brief> --since <previous job> --detach` — the runner attaches the fix delta plus the previous report, findings tagged IN-FIX / NEW / REPEAT.
Cadence, every tier: round 1 = every axis in ONE message, ≤ 40 tool calls each; round 2 = only the flagging reviewer re-runs its repro on the delta, ≤ 15 calls — no suite re-runs, no new axis.

Whoever wrote the fix never verifies it: a subagent-built fix → the Lead's cold read; a Lead-built fix → one read-only `universal-reviewer` pass (R4 → the strong pass).
- The external re-runs only when its previous report carried a BLOCKER and the fix delta is logic-bearing code; otherwise the internal reviewer verifies the fix delta alone.
- Author and reviewer disagree on merits → technical data > documented style guide > engineering principle > codebase consistency.

**Breaker.** Two rounds is the budget — review, then confirm the fixes; a third is a reassessment point. Triggers, any one:
- round 3 on one uncommitted tree (dispatches closer than 5 min are one round; `rolepod-cross-family --rounds` shows the state)
- blockers tagged IN-FIX two rounds running
- BLOCKER / MAJOR tagged NEW in files the previous round never touched, two rounds running
- the same defect class at a new site
- any REPEAT.

Then, in order:
0. **Stop** — no fix, no reviewer; `--collect` or `--kill` what runs.
1. **Ledger** — `docs/rolepod/handoffs/<feature>-breaker-<date>.md`: `## Rounds` (per round: found → hypothesis → changed → test result → came back), `## Class` (one root cause, its single point, every consumer — grep the call sites now), `## Decision` (options for the user).
2. **Class** — cannot name the class or its single point → ONE consult (the CLI's native advisor, else `rolepod-cross-family --kind consult --brief <ledger>`) asking exactly that; never a second blind fix.
3. **Class fix once** — one source of truth, every consumer calls it, per-site copies deleted; proof = a class test failing on ≥2 old sites + the consumer list checked off; NEW findings outside the class → `## Follow-ups`.
4. **One round** — `--since <job> --ledger <ledger> --detach` plus the internal strong reviewer on the class with the same two files. Round 4 is refused without the ledger; round 5 is refused outright. APPROVED / NITS → ship path.
5. **Split & stop** — REJECTED with any IN-FIX / REPEAT, or the user absent: commit the slices with no open finding, park the churning surface as a delta spec / Follow-ups, end the turn with the decision brief (rounds · class · options); a resume prompt restates the brief, never opens a round.

An advisor never substitutes for the §3 adversarial pass.

### 6. Author-side response

READ the round's merged findings without reacting → VERIFY each against the codebase → RESPOND with a technical ack or reasoned pushback → IMPLEMENT by provenance: INTRODUCED → fix now; EXPOSED → fix now only when it makes THIS change wrong, otherwise a user decision (money / auth) or `## Follow-ups`; ADJACENT → `## Follow-ups`, never fixed this round.

Clarify unclear findings before touching anything LINKED to them; order blocking → simple → complex, testing each. No gratitude phrases — "Fixed in <file:line>." is the whole reply.

**rolepod-brain:** `brain_note(agent: <reviewer id>, text: "avoid:|refine:|keep: <class>…")` per finding not applied as written; always on a user overrule. A test the author adds to close a finding is part of the fix delta — the next round's reviewer judges it; the author's own green run closes nothing.

## If a matching Rolepod agent is available

The §1 table names the reviewer per risk profile; the writer's unit tests are the floor; `qa-tester` joins only for user-visible behaviour.

## If no matching agent is available

Execute as Lead: read the diff and the touched files end-to-end with line numbers → run every §2 axis, tracing each claimed behavior through the seams → report per §4 (severity, file:line, TRACED / SUSPECTED) and record the missing adversarial pass as a LIMITATION.

## Output

The review report is the canonical artifact: `templates/review-report.md` — scope, risk surfaces, reviewers, severity-ordered findings, test verdict, recommendation.

Evidence log: append the line to `<git-root>/.rolepod/evidence/phase-log.jsonl` chained onto the next command you run anyway (`<cmd> && printf '…' >> phase-log.jsonl`), never as a standalone turn; skip silently outside a git repo. On a CLI without hooks the Lead writes every line itself.
Review line: `{"ts":"<iso8601>","phase":"review","verdict":"<APPROVED|APPROVED-WITH-NITS|REJECTED>","blockers":<n>}` (round 2+: add `"round":<n>,"infix":<n>,"repeat":<n>`).

**External evidence anchor.** The runner anchors the pass itself: raw output under `<git-root>/.rolepod/evidence/external/<utc-ts>-<cli>.txt` (teed at invoke) plus its own phase-log line (`"reviewer":"external"`, cli, family, `model:"default"`, raw path).
- The gate counts it as the strong pass only if that raw file exists and is ≥ 500 bytes — a bare claim, a hand-typed line, or a hand-rolled external call without the anchor is ignored by design.
- The Lead's merged verdict line above is still appended separately.

## References

Load only when needed:
- `references/external-review-routing.md` — cross-CLI review routing and degradation.
- `references/receiving-findings.md` — author-side playbook.
- `examples/finding-examples.md` — actionable vs vague findings.

## Hard stops

- High-risk diff with no adversarial review → `security-engineer` first.
- Reviewer is the author (a Lead-built fix in the §5 loop included) → fresh reviewer required.
- "Tests pass" offered as the only review evidence → do the axis walk.
- Author implementing findings without verifying any → §6 first.
- Multi-finding fix in progress while a linked item is unclear → clarify first.
- A dispatched reviewer still running and the next action edits a diff file or runs `git stash / reset / checkout` → stop; the round is not over.

## Next phase

- Review-only ask → none; stop after the report (Boundary). Otherwise:
  - `finish-work` for the merge gate — unless the plan has unchecked tasks: `implement-plan` first.
  - If `finish-work` is not available, present findings + recommendation and ask the user which finish path they want.
