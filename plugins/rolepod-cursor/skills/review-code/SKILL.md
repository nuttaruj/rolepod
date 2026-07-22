---
name: review-code
description: Use before merging or shipping — review code with risk-appropriate adversarial pressure across correctness, security, performance, UI, and architecture. Pick reviewer by risk profile. Phase = Review.
---

# Review Code

Review-phase entry skill. Apply risk-appropriate review pressure to a finished change. Multi-axis read across correctness, security, performance, UI, and architecture, with adversarial review for high-risk diffs.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER merge code on a high-risk surface (auth, billing, payments, credits, migration, data deletion, secrets, tokens, crypto, permissions, security) without an adversarial fresh-context review.
2. NEVER let the author — or, for the adversarial pass, the author's own model — be the final reviewer of their own change. The external adversarial review runs on a model **family** different from the Lead's; the vertical fallback (same family, stronger tier) never satisfies it — it only upgrades the Lead floor and is recorded as a limitation.
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
- No blockers → `finish-work`.

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

**External adversarial review — route by model strength, never the Lead's own model.** Iron Rule 2: the adversarial pass runs on a model **different from the Lead's**. Detect the pool — the Lead is this session's CLI; externals are the others on PATH (`codex` / `gemini` / `claude`). High-risk OR multi-file diff with an external available → routing to it is mandatory. `qa-tester` + the Lead's own multi-axis read are the floor, and backstop any reviewer that is missing or fails. Per-CLI axis strengths, the Lead-exclusion rule, and degradation: `references/external-review-routing.md`.

### 2. Multi-axis read

For every diff, scan:
- **Intent** — state the goal in one sentence. Is there a simpler/smaller way, or should the change exist at all? Surface this before the line-by-line read.
- **Trace** — the diff is the entry point, not the scope. For each behavior the change claims, walk the real path (entry → call sites → branches → state → exit) through the seams into unchanged code — bugs hide at the seams, and every surprise on the walk is findings signal. Bound the walk to the change's claims and seams (auditing untouched code is scope creep — file it as a Question, not a BLOCKER); use the code-intel index (callers / impact) when connected. The walk runs in the reviewer's context, never as Lead bulk reads.
- **Correctness** — does the logic match the spec? Edge cases? Off-by-one? Null / undefined / empty?
- **Security** — input validation, auth check, secret handling, SSRF, injection, token leak in logs
- **Performance** — N+1, blocking calls, unbounded loops, big payloads, missing index
- **Architecture** — does it match existing patterns? Source of truth violations? New abstraction with one user?
- **UI** — a11y, hierarchy, consistency, platform conventions if applicable
- **Tests** — strong assertions? Mocks at the right boundary? Race coverage for concurrent code?

### 3. Adversarial mode for high risk

Fresh context. Reviewer reads only the artifact + acceptance criteria. Tries to make the change fail. Looks for what is missing as hard as what is present.

### 4. Report findings, severity-ordered

Fill `templates/review-report.md`. Each finding names file:line, the issue, why it matters, and a fix direction — never a silent rewrite (Iron Rule 4). Label each finding's evidence: **TRACED** (path walked; holds or fails at a named step) or **SUSPECTED** (pattern-level; author must verify per §6) — "the change claims X" and "I traced X" are different statements. A clean review is never a bare APPROVED: the report's Claims-traced section states what was walked and which axes ran, so coverage is judgeable.

### 5. Fix-verify loop

After the author fixes, re-read the diff. Confirm fixes don't introduce new BLOCKER / MAJOR issues. The reviewer who flagged the issue is not the final authority on whether it is fixed — Lead or qa-tester gives the final APPROVED.

When author and reviewer disagree on the merits, resolve by precedence: technical data > documented style guide > engineering principle > codebase consistency.

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
7. Walk the architecture axis: pattern match, source of truth
8. Walk the test axis: assertion strength, mock boundary
9. Report findings severity-ordered with file:line, TRACED vs SUSPECTED labeled

## Output

The review report is the canonical artifact: `templates/review-report.md`. It carries scope, risk surfaces, reviewers, severity-ordered findings, the test verdict, and the recommendation. Do not restate the report shape here; the template is the single source.

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

- If `finish-work` is available, continue there for the merge gate.
- If `finish-work` is not available, present the findings + recommendation to the user and ask which finish path they want.
