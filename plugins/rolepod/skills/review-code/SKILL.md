---
name: review-code
description: Use before merging or shipping — review code with risk-appropriate adversarial pressure across correctness, security, performance, UI, and architecture. Pick reviewer by risk profile. Phase = Review.
when_to_use: when a change is ready to ship and needs a second-pass read for correctness, regressions, security, performance, architecture, or UI compliance before merge
tier: 1
phase: review
---

# Review Code

Review-phase entry skill. Apply risk-appropriate review pressure to a finished change. Multi-axis read across correctness, security, performance, UI, and architecture, with adversarial review for high-risk diffs.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER merge code on a high-risk surface (auth, billing, payments, credits, migration, data deletion, secrets, tokens, crypto, permissions, security) without an adversarial fresh-context review.
2. NEVER let the author — or, for the adversarial pass, the author's own model — be the final reviewer of their own change. The external adversarial review runs in a **CLI** different from the Lead's, on that CLI's own default model (the same vendor is acceptable — the other harness, context and defaults are the decorrelation); the vertical fallback (same CLI, stronger tier) never satisfies it — nor does an inline advisor (Claude Code Advisor mode): it advises the author inside the author's own context. Both only upgrade the Lead floor and are recorded as a limitation.
3. NEVER skip review because "tests pass". Tests prove the assertion, not the design.
4. Findings before fixes — the whole round's findings, never the first report's. List issues with severity first; do not silently rewrite.
5. Author MUST verify findings against the codebase before implementing. No performative agreement ("you're absolutely right!", "great point!", "thanks!"). No blind implementation. Clarify all unclear items before partial implementation — findings may be linked.
</EXTREMELY-IMPORTANT>

## When to use

- Change is implementation-complete and verified
- High-risk surface touched (auth / billing / payments / credits / migration / data deletion / secrets / tokens / crypto / permissions / security)
- Public API or schema contract changed
- Performance-sensitive code path
- UI shipped to end users
- Subagent returned COMPLETED — second-pass read
- Recurring bug in similar surface — adversarial pressure

Skip when:
- Pure docs / typo / whitespace
- The user explicitly accepts the change with no review
- The change is R1: ≤5 lines, single file, zero logic (user-facing string text alone counts as zero off high-risk paths), NOT high-risk

## Boundary

Owns:
- Risk-appropriate second-pass review.
- Finding discovery, severity ordering, adversarial read.

Does not own:
- Silent implementation fixes.
- Final merge / PR decision.
- Re-running the full verification suite unless needed to validate a finding.

Return / hand off:
- Findings need fixes → `implement-plan` or `debug-issue`.
- Fixes landed → `check-work`.
- No blockers but the driving plan still has unchecked tasks → back to `implement-plan` (next task); Ship asks once per plan, not once per phase.
- No blockers, plan exhausted (or no plan) → `finish-work`.

## Inputs to gather

- The diff — pin base + target and name the form: committed branch → `<base>...HEAD`; uncommitted work → `git diff HEAD` (staged + unstaged together — `--cached` alone is a slice, and the runner refuses a slice whose files carry tree edits it does not contain, exit 7; `--partial-ok` only when the user asked for the staged part; past ~15 files / ~800 lines the diff is two concerns — split before dispatch, reviewers read what fits)
- The spec / plan / acceptance criteria
- Touched files end-to-end
- The risk profile (high-risk surface? new dep? schema change?)
- Available reviewers (qa-tester, security-engineer, universal-reviewer, external CLI reviewers if installed)

## Workflow

### 1. Pick reviewer by risk

| Risk profile | Reviewer |
|--------------|----------|
| High-risk surface (auth / billing / payments / credits / migration / data deletion / secrets / tokens / crypto / permissions / security) | `security-engineer` + adversarial fresh-context |
| Correctness / business logic | `qa-tester` |
| Performance regression risk | `performance-engineer` |
| UI / interaction / a11y | `ui-ux-designer` |
| Architecture / cross-module | `system-architect` |
| Generic quality / DRY / smell | `universal-reviewer` |

Rigor-tier mapping: R1 → no review and no re-read turn (the edit tool's echo is the evidence — §Skip); R2 → the qa-tester floor (balanced, the diff alone — the author never reviews own logic, a Lead-built R2 included); when the matched row is not qa-tester, add ONE concern-matched reviewer at **balanced** tier — pass the balanced model explicitly on a balanced role, but leave a `universal-reviewer` call model-less (the dispatch hook sets its tier; a balanced pin voids the gate) and keep strong reserved for final-pass / adversarial contexts; R3 → row match as usual **plus** the cross-family external on the diff's dominant axis when the pool is usable (any logic-bearing diff; doc / rename / config-only exempt); R4 (high-risk) → full adversarial floor, never less (the router's comment/blank-only carve-out — 1 file, ≤5 lines, LOGIC_COUNT=0 — lands here as R2 + ONE strong reviewer, cross-family anchor still required while a pool is enabled).

**Satellite-first strong pass:** a usable cross-family external (routing: `references/external-review-routing.md`; one command: `rolepod-cross-family --kind review --brief <brief> --attach <diff> --detach` — read-only, the external's own default model, anchored by the runner) IS the R4 strong adversarial pass; the commit gate counts only the runner's anchor.

**Detach by default for review:** the runner returns a job id at once and runs the chain (first member → fallbacks) in its own process group with each member's budget (`timeout=` in the config, review default 30 min); dispatch the qa-tester floor and, on money / auth, the internal strong reviewer in the same breath, then keep working OUTSIDE the diff (a plan task on disjoint files) or end the turn — `rolepod-cross-family --collect <job-id>` waits up to the budget, so run it in a background call where the harness has one (Claude Code: Bash `run_in_background`): one wake-up, no polling turns; the commit gate names the job if you get there first. Foreground (no `--detach`) is for small diffs only: the harness caps it at 600 s and a slow member (e.g. Codex at its owner's `max` effort) is killed mid-run.

Dispatch an INTERNAL strong reviewer (security-engineer / universal-reviewer) when (a) cross-family is off (opt-in not given / `none` — exit 5) or the runner reports no usable member (exit 3 every member failed / exit 4 enabled-but-empty — logged; the gate then accepts the internal pass), (b) **money / auth surface** — billing / payments / credits / auth / crypto / secrets / data deletion (or the gate's money-term content hit): run BOTH passes in ONE dispatch, external for decorrelation + internal strong for project-context depth; the commit gate requires both anchors here (migration / permission / token paths: external alone), (c) **the external came back weak** — family `unknown` in the receipt, no TRACED finding, or a verdict with no claims walked: add the internal strong reviewer rather than trusting a thin pass, (d) an apex trigger holds (irreversible / live money movement / novel design / churn — BOTH passes, apex rung), or (e) re-reading fixes in the §5 loop. When the internal strong reviewer runs, it runs at STRONG class even when the Lead is balanced-class: on Claude Code the dispatch hook lifts a model-less security-engineer / universal-reviewer call to the strong alias under a low Lead (never pass a balanced model on them — the commit gate will not count it); elsewhere pass an explicit strong-class override. qa-tester is the balanced test floor by design (hard balanced pin) — it writes and runs the tests; it is not the strong pass, and the commit gate does not count it as one.

**Apex escalation — strong is the R4 default; the CLI's ceiling is a trigger, not a habit.** Strong review asks "done right per the existing pattern?"; apex — the strongest model the CLI exposes — asks "is the pattern itself right?". Escalate the override to apex only when one holds: (1) irreversible with no rollback — destructive migration, key rotation, live money movement; (2) novel design on the surface — no existing pattern to diff against; (3) deep cross-system reasoning — races on financial invariants, distributed consistency; (4) the previous strong round missed blockers (churn); (5) user asks. No trigger → strong stands and apex idles. A CLI whose strong pin already IS its ceiling (Codex `sol`; Gemini) collapses apex into strong. The ladder spans the user's opted-in model set, never a full aggregator catalog — a rung costlier than anything the user configured is a cost decision to surface first, and a set whose ceiling sits below opus-class still gets the full review with the depth cap recorded as a LIMITATION. Either way the dispatch line's `override` field records the rung sent.

**More than one reviewer fires → dispatch them in ONE message.** The qa-tester floor, the risk-matched specialist, and the external adversarial reviewer all read the same frozen diff with no shared state — they run concurrently, not in sequence. That dispatch plus the Lead's own read is ONE **review round**; it ends when the LAST member returns (`--collect` for a detached job). Until then the diff is frozen for real: no edit to a file it touches, no `git stash / reset / checkout / add / commit` (a red-proof revert runs in a throwaway worktree, never in place) — reviewers read the live tree for context, so one early fix turns every in-flight verdict into an artifact and re-runs the external. Reviews land as each returns; the report merges them severity-ordered, deduped by file:line + root cause (the Lead's own findings join the pile like any reviewer's), and §6 starts on the merged list, never on the first report; only the §5 fix-verify loop is serial (fixes change the diff). Map specialist vocabularies onto the report's scale: CRITICAL/HIGH → BLOCKER, WARNING/MEDIUM → MAJOR, SUGGESTION/LOW → MINOR.

**External adversarial review — a different CLI, never the Lead's own.** Iron Rule 2: the adversarial pass runs in a CLI **different from the Lead's**, on that CLI's own default model (same vendor allowed — the harness differs). The pool is the user's choice and **opt-in**: `<git-root>/.rolepod/cross-family`, then `~/.rolepod/cross-family` (one CLI per line — `codex` / `claude` / `agy` / `cursor` / `opencode`), minus the Lead's family; no file or `none` = off, and rolepod never turns it on unasked (the session context asks you to put the question to the user once; `rolepod-cross-family --pool` shows candidates). Enabled, R3+ or high-risk, on any **logic-bearing** diff, with a usable member → routing to it is mandatory (doc / rename / config-only diffs are exempt — one concern-matched reviewer suffices; R2 single-file logic diffs stay internal unless the user asks). `qa-tester` + the Lead's own multi-axis read are the floor, and backstop any reviewer that is missing or fails. Reviewer dispatch impossible entirely (user forbade agents / no subagent support) → Lead cold self-review stands in and the report records it as a LIMITATION — surface the conflict, never self-set a bypass env. Per-CLI axis strengths, the Lead-exclusion rule, and degradation: `references/external-review-routing.md`.

### 2. Multi-axis read

For every diff, scan:
- **Intent** — state the goal in one sentence. Is there a simpler/smaller way, or should the change exist at all? Surface this before the line-by-line read.
- **Trace** — the diff is the entry point, not the scope. For each behavior the change claims, walk the real path (entry → call sites → branches → state → exit) through the seams into unchanged code — bugs hide at the seams, and every surprise on the walk is findings signal. Bound the walk to the change's claims and seams (auditing untouched code is scope creep — file it as a Question, not a BLOCKER); use the code-intel index (callers / impact) when connected. The walk runs in the reviewer's context, never as Lead bulk reads.
- **Correctness** — does the logic match the spec? Edge cases? Off-by-one? Null / undefined / empty?
- **Security** — input validation, auth check, secret handling, SSRF, injection, token leak in logs
- **Performance** — N+1, blocking calls, unbounded loops, big payloads, missing index
- **Architecture** — does it match existing patterns? Source of truth violations? New abstraction with one user? Hand-rolled logic the stdlib already ships, or a dep / custom code duplicating a platform feature (native input, CSS, DB constraint, `Intl.*`)? A simplification finding must name the concrete replacement. The project declares a module boundary map (CLAUDE.md / ADR) → check every NEW cross-module import against it; a dependency-direction reversal or undeclared crossing is a BLOCKER — spaghetti arrives one import at a time, and per-diff is the only place it is cheap to stop.
- **UI** — a11y, hierarchy, consistency, platform conventions if applicable
- **Tests** — strong assertions? Mocks at the right boundary? Race coverage for concurrent code? A diff that *modifies an existing test* on the way to green is a finding until justified — loosened assertion, raised tolerance, deleted case, added skip / only, snapshot updated to absorb the failure. The old test was the contract; changing the test instead of the code needs its own stated why.

### 3. Adversarial mode for high risk

Fresh context. Reviewer reads only the artifact + acceptance criteria. Tries to make the change fail. Looks for what is missing as hard as what is present.

### 4. Report findings, severity-ordered

Fill `templates/review-report.md`. Each finding names file:line, the issue, why it matters, and a fix direction — never a silent rewrite (Iron Rule 4). Label each finding's evidence: **TRACED** (path walked; holds or fails at a named step) or **SUSPECTED** (pattern-level; author must verify per §6) — "the change claims X" and "I traced X" are different statements — and its provenance: **INTRODUCED** (this diff caused it), **EXPOSED** (pre-existing, on a path this diff changes) or **ADJACENT** (pre-existing, path untouched; listed once, never drives the verdict — the diff is the scope). A clean review is never a bare APPROVED: the report's Claims-traced section states what was walked and which axes ran, so coverage is judgeable.

### 5. Fix-verify loop

After the author fixes, re-read the diff — round 2+ is `rolepod-cross-family --kind review --brief <brief> --since <previous job> --detach`: the runner attaches the fix delta (its snapshot at the previous dispatch → now) plus the previous report, so the budget goes to the fixes, not the cumulative diff, and every finding comes back tagged IN-FIX (inside the previous round's fixes) / NEW / REPEAT (still open); the internal round-2 reviewer gets the same two files; the phase-log line carries the counts. Confirm fixes don't introduce new BLOCKER / MAJOR issues. The reviewer who flagged the issue is not the final authority on whether it is fixed, and neither is whoever wrote the fix: a subagent-built fix → qa-tester or the Lead's cold read; a Lead-built fix → qa-tester at balanced (R4 → the internal strong reviewer), never the Lead — the author sides with the author. The external re-runs only when the fix diff itself tiers R3+.

When author and reviewer disagree on the merits, resolve by precedence: technical data > documented style guide > engineering principle > codebase consistency.

**Breaker.** Triggers, any one: this would be review round 3 on one uncommitted tree (the runner and the hooks count rounds since the last commit — reviewer dispatches closer than 5 min are one round; `rolepod-cross-family --rounds` shows the state); blockers tagged IN-FIX two rounds in a row; BLOCKER / MAJOR tagged NEW in files the previous round never touched two rounds in a row; the same defect class at a new site (churn even when tagged NEW); any REPEAT. Then, in order, budget fixed: **0 stop** — no fix, no reviewer on this tree; `--collect` or `--kill` what is running. **1 ledger** — `docs/rolepod/handoffs/<feature>-breaker-<date>.md` with `## Rounds` (one line per round: found → changed → came back), `## Class` (one root cause, its single point, every consumer — grep the call sites, code-intel callers when connected, listed now, not found by review) and `## Decision` (the options for the user). **2 class** — cannot name the class or its single point → ONE consult (vertical advisor when the CLI has one — Claude Code Advisor mode is this channel — else `rolepod-cross-family --kind consult --brief <ledger>`) asking exactly that; never a second blind fix. **3 class fix once** — one source of truth, every consumer calls it, per-site copies deleted; proof = a class test that fails on ≥2 old sites + the consumer list checked off; NEW findings outside the class → `## Follow-ups`. **4 one round** — `rolepod-cross-family --kind review --since <job> --ledger <ledger> --detach` plus the internal reviewer with the same two files (round 4 is refused without the ledger; round 5 is refused outright). APPROVED / NITS → ship path. **5 split & stop** — REJECTED with any IN-FIX / REPEAT, or the user absent (an auto-resume prompt): commit the slices with no open finding, park the churning surface as a delta spec / Follow-ups, end the turn with the decision brief (rounds · class · options); a resume prompt restates the brief, never opens a round. A vertical or cross-family *advisor* never substitutes for the §3 adversarial pass.

### 6. Author-side response

When the author is Lead receiving findings from a reviewer subagent or external CLI reviewer: READ the round's merged findings (every reviewer returned, deduped) without reacting → VERIFY each against the codebase (does it hold for THIS code?) → RESPOND with a technical ack or reasoned pushback → IMPLEMENT by provenance: INTRODUCED → fix now; EXPOSED → fix now only when it makes THIS change wrong, otherwise it goes to the user as a decision (money / auth) or to `## Follow-ups`; ADJACENT → `## Follow-ups`, never fixed in this round — fixing every finding a reviewer can see is how one change becomes 40 files. Clarify unclear findings before touching any finding LINKED to them — a proven finding independent of every open question proceeds now; order: blocking → simple → complex, testing each individually. No gratitude phrases ("You're absolutely right!" / "Thanks for catching that!") — the diff shows you heard; "Fixed in <file:line>." is the whole reply.

The full playbook — forbidden-phrase list, pushback discipline, GitHub thread replies (`gh api .../replies`), YAGNI grep, source-specific handling — lives in `references/receiving-findings.md`.

## If a matching Rolepod agent is available

Delegate the review to the closest specialist:

- `qa-tester` — universal floor, never skip
- `security-engineer` — adds adversarial pressure on high-risk diffs
- `performance-engineer` — perf regressions
- `ui-ux-designer` — UI / a11y / visual polish
- `system-architect` — architecture decisions
- `universal-reviewer` — generic DRY / smell / structure

Brief: diff + spec + acceptance criteria + the risk profile + the claimed behaviors to trace end-to-end + which reviewer roles you already invoked.

## If no matching agent is available

Execute as Lead with this minimum viable checklist:

1. Read the diff end-to-end with line numbers
2. Read the touched files end-to-end, not just the diff regions
3. Trace each claimed behavior end-to-end (entry → branches → state → exit), including the seams into unchanged code
4. Walk the correctness axis: logic, edges, null, off-by-one
5. Walk the security axis: input validation, auth, secret, SSRF, injection
6. Walk the performance axis: N+1, blocking, unbounded
7. Walk the architecture axis: pattern match, source of truth, new cross-module imports vs the declared boundary map
8. Walk the test axis: assertion strength, mock boundary
9. Report findings severity-ordered with file:line, TRACED vs SUSPECTED labeled

## Output

The review report is the canonical artifact: `templates/review-report.md`. It carries scope, risk surfaces, reviewers, severity-ordered findings, the test verdict, and the recommendation. Do not restate the report shape here; the template is the single source.

Also append one line to `<git-root>/.rolepod/evidence/phase-log.jsonl` — `{"ts":"<iso8601>","phase":"review","verdict":"<APPROVED|APPROVED-WITH-NITS|REJECTED>","blockers":<n>}` (round 2+: add `"round":<n>,"infix":<n>,"repeat":<n>` — the tag counts) — inside the next Bash call you make anyway (the finish gates' `git diff`, the commit), never as a standalone turn (fail-open outside a git repo).

**External strong pass — evidence anchor.** The runner anchors the pass itself: raw output under `<git-root>/.rolepod/evidence/external/<utc-ts>-<cli>.txt` (teed at invoke, never retyped) plus a phase-log line `{"phase":"review","reviewer":"external","cli":"<cli>","family":"<family>","model":"default","raw":"external/<file>.txt"}`. The gate counts it as the strong pass only if that raw file exists and is ≥ 500 bytes — a bare claim, a hand-typed line, or a hand-rolled `codex exec` without the anchor is ignored by design. The Lead's own merged verdict line (above) is still appended separately.

## Examples

Non-blocking — read only when unsure whether a finding is actionable:
- `examples/finding-examples.md` — a security BLOCKER and a performance MAJOR, each an actionable/vague pair with a "why good wins" table. Read the whole file; the contrast is the lesson.

## References

Load only when the task needs it:
- `references/external-review-routing.md` — cross-CLI adversarial review: model strengths, Lead-exclusion, degradation
- `references/receiving-findings.md` — author-side deep playbook: forbidden phrases catalog, source-specific handling (user / external / conflict), YAGNI grep before adding, pushback playbook, common mistakes

## Hard stops

- High-risk surface diff with no adversarial review → stop, route to `security-engineer` first
- Reviewer is the author of the change (a Lead-built fix in the §5 loop included) → stop, fresh reviewer required
- "Tests pass" offered as the only review evidence → not a review; do the axis walk
- Author about to implement findings without verifying any of them against the codebase → stop, run the §6 response pattern
- Multi-finding fix in progress while a linked item is unclear → stop, clarify before any partial implementation
- A dispatched reviewer is still running and the next action edits a file in the diff, or runs `git stash / reset / checkout` → stop; the round is not over (§1)

## Full Rolepod enhancement

Full Rolepod improves this phase by adding the qa-tester floor, external adversarial CLI reviewers (any installed CLI whose model differs from the Lead's) routed by risk, hooks that block subagent commits, and the two-stage fresh-context review pattern for delegated work.

## Next phase

- If `finish-work` is available, continue there for the merge gate — unless the driving plan still has unchecked tasks: loop back to `implement-plan` first.
- If `finish-work` is not available, present the findings + recommendation to the user and ask which finish path they want.
