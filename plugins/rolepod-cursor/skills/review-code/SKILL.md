---
name: review-code
description: Use before merging or shipping — review code with risk-appropriate adversarial pressure across correctness, security, performance, UI, and architecture. Pick reviewer by risk profile. Phase = Review.
---

# Review Code

Review-phase entry skill. Apply risk-appropriate review pressure to a finished change. Multi-axis read across correctness, security, performance, UI, and architecture, with adversarial review for high-risk diffs.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER merge code on a high-risk surface (auth, billing, payments, credits, migration, data deletion, secrets, tokens, crypto, permissions, security) without an adversarial fresh-context review.
2. NEVER let the author — or, for the adversarial pass, the author's own model — be the final reviewer of their own change. The external adversarial review runs on a model **family** different from the Lead's; the vertical fallback (same family, stronger tier) never satisfies it — nor does an inline advisor (Claude Code Advisor mode): it advises the author inside the author's own context. Both only upgrade the Lead floor and are recorded as a limitation.
3. NEVER skip review because "tests pass". Tests prove the assertion, not the design.
4. Findings before fixes. List issues with severity first; do not silently rewrite.
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
- The change is < 5 lines, single file, zero logic, NOT high-risk

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

- The diff (`git diff` or PR view)
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

Rigor-tier mapping: R1 → Lead cold self-review only (`git diff` + re-read from disk); R2 → ONE concern-matched reviewer from the table at **balanced** tier (strong stays reserved for final-pass / adversarial contexts); R3 → row match as usual; R4 (high-risk) → full adversarial floor, never less. **Satellite-first strong pass:** a healthy cross-family external reviewer (routing: `references/external-review-routing.md`) IS the R4 strong adversarial pass — anchor it per §Output's evidence line or the commit gate will not count it. Dispatch an INTERNAL strong reviewer (security-engineer / universal-reviewer) only when (a) no healthy cross-family external exists, (b) an apex trigger holds (irreversible / live money movement — then run BOTH passes), or (c) re-reading fixes in the §5 loop. When the internal strong reviewer runs, it runs at STRONG class even when the Lead is balanced-class: on Claude Code the dispatch hook lifts a model-less security-engineer / universal-reviewer call to the strong alias under a low Lead (never pass a balanced model on them — the commit gate will not count it); elsewhere pass an explicit strong-class override. qa-tester is the balanced test floor by design (hard balanced pin) — it writes and runs the tests; it is not the strong pass, and the commit gate does not count it as one.

**Apex escalation — strong is the R4 default; the CLI's ceiling is a trigger, not a habit.** Strong review asks "done right per the existing pattern?"; apex — the strongest model the CLI exposes — asks "is the pattern itself right?". Escalate the override to apex only when one holds: (1) irreversible with no rollback — destructive migration, key rotation, live money movement; (2) novel design on the surface — no existing pattern to diff against; (3) deep cross-system reasoning — races on financial invariants, distributed consistency; (4) the previous strong round missed blockers (churn); (5) user asks. No trigger → strong stands and apex idles. A CLI whose strong pin already IS its ceiling (Codex `sol`; Gemini) collapses apex into strong. The ladder spans the user's opted-in model set, never a full aggregator catalog — a rung costlier than anything the user configured is a cost decision to surface first, and a set whose ceiling sits below opus-class still gets the full review with the depth cap recorded as a LIMITATION. Either way the dispatch line's `override` field records the rung sent.

**More than one reviewer fires → dispatch them in ONE message.** The qa-tester floor, the risk-matched specialist, and the external adversarial reviewer all read the same frozen diff with no shared state — they run concurrently, not in sequence. Serialize only the §5 fix-verify loop (fixes change the diff). Reviews land as each returns; the report merges them severity-ordered.

**External adversarial review — route by model strength, never the Lead's own model.** Iron Rule 2: the adversarial pass runs on a model **different from the Lead's**. Detect the pool — the Lead is this session's CLI; externals are the others on PATH (`codex` / `gemini` / `claude`). High-risk OR multi-file **logic-bearing** diff with an external available → routing to it is mandatory (doc / rename / config-only multi-file diffs are exempt — one concern-matched reviewer suffices). `qa-tester` + the Lead's own multi-axis read are the floor, and backstop any reviewer that is missing or fails. Reviewer dispatch impossible entirely (user forbade agents / no subagent support) → Lead cold self-review stands in and the report records it as a LIMITATION — surface the conflict, never self-set a bypass env. Per-CLI axis strengths, the Lead-exclusion rule, and degradation: `references/external-review-routing.md`.

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

Fill `templates/review-report.md`. Each finding names file:line, the issue, why it matters, and a fix direction — never a silent rewrite (Iron Rule 4). Label each finding's evidence: **TRACED** (path walked; holds or fails at a named step) or **SUSPECTED** (pattern-level; author must verify per §6) — "the change claims X" and "I traced X" are different statements. A clean review is never a bare APPROVED: the report's Claims-traced section states what was walked and which axes ran, so coverage is judgeable.

### 5. Fix-verify loop

After the author fixes, re-read the diff. Confirm fixes don't introduce new BLOCKER / MAJOR issues. The reviewer who flagged the issue is not the final authority on whether it is fixed — Lead or qa-tester gives the final APPROVED.

When author and reviewer disagree on the merits, resolve by precedence: technical data > documented style guide > engineering principle > codebase consistency.

**Fix-round circuit breaker.** A round whose reviewer finds blockers *in the previous round's fixes* is a churn signal — the per-bug escalation rule never trips here because each round's blockers are new targets, so count at round level: two consecutive churn rounds → stop point-patching and climb the ladder in order: (1) zoom out — can the blocker class be closed wholesale (design-level fix) instead of per-site? (2) escalate the fix design vertically — one consult at the tier above the Lead (opus → fable-class) when the CLI exposes one, and Claude Code with native Advisor mode on uses it as THIS channel (inline, one consult — never a second parallel one); same shape as debug-issue §9: one advisor, one advisor-informed round, never another blind fix; (3) vertical exhausted or the misses smell family-shaped → one cross-family consult (advisor, not another reviewer); (4) still churning → surface to the user with the split option: merge the stable slices, isolate the churning surface into its own PR. A vertical or cross-family *advisor* here never substitutes for the §3 adversarial pass — advising on the fix and reviewing the diff stay separate roles.

### 6. Author-side response

When the author is Lead receiving findings from a reviewer subagent or external CLI reviewer: READ all findings without reacting → VERIFY each against the codebase (does it hold for THIS code?) → RESPOND with a technical ack or reasoned pushback → IMPLEMENT. Clarify ALL unclear findings before touching any — findings may be linked; order: blocking → simple → complex, testing each individually. No gratitude phrases ("You're absolutely right!" / "Thanks for catching that!") — the diff shows you heard; "Fixed in <file:line>." is the whole reply.

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

Also append one line to `<git-root>/.rolepod/evidence/phase-log.jsonl` — `{"ts":"<iso8601>","phase":"review","verdict":"<APPROVED|APPROVED-WITH-NITS|REJECTED>","blockers":<n>}` (fail-open outside a git repo).

**External strong pass — evidence anchor.** A cross-family external review counts toward the commit gate only when anchored: save the reviewer CLI's raw output to `<git-root>/.rolepod/evidence/external/<utc-ts>-<family>.txt` (tee at invoke time, never retyped) and extend the review line with `"reviewer":"external","family":"<codex|claude|gemini>","model":"<id>","raw":"external/<file>.txt"`. The gate counts it as the strong pass only if the raw file exists and is ≥ 500 bytes — a bare claim without the file is ignored by design.

## Examples

Non-blocking — read only when unsure whether a finding is actionable:
- `examples/finding-examples.md` — a security BLOCKER and a performance MAJOR, each an actionable/vague pair with a "why good wins" table. Read the whole file; the contrast is the lesson.

## References

Load only when the task needs it:
- `references/external-review-routing.md` — cross-CLI adversarial review: model strengths, Lead-exclusion, degradation
- `references/receiving-findings.md` — author-side deep playbook: forbidden phrases catalog, source-specific handling (user / external / conflict), YAGNI grep before adding, pushback playbook, common mistakes

## Hard stops

- High-risk surface diff with no adversarial review → stop, route to `security-engineer` first
- Reviewer is the author of the change → stop, fresh reviewer required
- "Tests pass" offered as the only review evidence → not a review; do the axis walk
- Author about to implement findings without verifying any of them against the codebase → stop, run the §6 response pattern
- Multi-finding fix in progress while items 4-5 remain unclear → stop, clarify all before any partial implementation

## Full Rolepod enhancement

Full Rolepod improves this phase by adding the qa-tester floor, external adversarial CLI reviewers (any installed CLI whose model differs from the Lead's) routed by risk, hooks that block subagent commits, and the two-stage fresh-context review pattern for delegated work.

## Next phase

- If `finish-work` is available, continue there for the merge gate — unless the driving plan still has unchecked tasks: loop back to `implement-plan` first.
- If `finish-work` is not available, present the findings + recommendation to the user and ask which finish path they want.
