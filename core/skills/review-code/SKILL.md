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
1. NEVER merge code on a high-risk surface (auth, billing, migration, secret, crypto, token, payment) without an adversarial fresh-context review.
2. NEVER let the author also be the final reviewer of their own change.
3. NEVER skip review because "tests pass". Tests prove the assertion, not the design.
4. Findings before fixes. List issues with severity first; do not silently rewrite.
</EXTREMELY-IMPORTANT>

## When to use

- Change is implementation-complete and verified
- High-risk surface touched (auth / billing / migration / secret / payment)
- Public API or schema contract changed
- Performance-sensitive code path
- UI shipped to end users
- Subagent returned COMPLETED — second-pass read
- Recurring bug in similar surface — adversarial pressure

Skip when:
- Pure docs / typo / whitespace
- The user explicitly accepts the change with no review
- The change is < 5 lines, single file, zero logic, NOT high-risk

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
| High-risk surface (auth / billing / migration / secret / payment) | `security-engineer` + adversarial fresh-context |
| Correctness / business logic | `qa-tester` |
| Performance regression risk | `performance-engineer` |
| UI / interaction / a11y | `ui-ux-designer` |
| Architecture / cross-module | `system-architect` |
| Generic quality / DRY / smell | `universal-reviewer` |

When external reviewer CLIs are installed (Codex / Gemini), route per `reviewer-flow` knowledge: Codex for correctness + security adversarial, Gemini for breadth and cross-file. qa-tester is the universal floor and the fallback when externals fail.

### 2. Multi-axis read

For every diff, scan:
- **Correctness** — does the logic match the spec? Edge cases? Off-by-one? Null / undefined / empty?
- **Security** — input validation, auth check, secret handling, SSRF, injection, token leak in logs
- **Performance** — N+1, blocking calls, unbounded loops, big payloads, missing index
- **Architecture** — does it match existing patterns? Source of truth violations? New abstraction with one user?
- **UI** — a11y, hierarchy, consistency, platform conventions if applicable
- **Tests** — strong assertions? Mocks at the right boundary? Race coverage for concurrent code?

### 3. Adversarial mode for high risk

Fresh context. Reviewer reads only the artifact + acceptance criteria. Tries to make the change fail. Looks for what is missing as hard as what is present.

### 4. Report findings, severity-ordered

```
BLOCKER (must fix before merge)
- <file:line>: <issue>

MAJOR (should fix or document)
- <file:line>: <issue>

MINOR (nice to fix)
- <file:line>: <issue>

QUESTIONS
- <file:line>: <unclear>
```

### 5. Fix-verify loop

After the author fixes, re-read the diff. Confirm fixes don't introduce new BLOCKER / MAJOR issues. The reviewer who flagged the issue is not the final authority on whether it is fixed — Lead or qa-tester gives the final APPROVED.

## If a matching Rolepod agent is available

Delegate the review to the closest specialist:

- `qa-tester` — universal floor, never skip
- `security-engineer` — adds adversarial pressure on high-risk diffs
- `performance-engineer` — perf regressions
- `ui-ux-designer` — UI / a11y / visual polish
- `system-architect` — architecture decisions
- `universal-reviewer` — generic DRY / smell / structure

Brief: diff + spec + acceptance criteria + the risk profile + which reviewer roles you already invoked.

## If no matching agent is available

Execute as Lead with this minimum viable checklist:

1. Read the diff end-to-end with line numbers
2. Read the touched files end-to-end, not just the diff regions
3. Walk the correctness axis: logic, edges, null, off-by-one
4. Walk the security axis: input validation, auth, secret, SSRF, injection
5. Walk the performance axis: N+1, blocking, unbounded
6. Walk the architecture axis: pattern match, source of truth
7. Walk the test axis: assertion strength, mock boundary
8. Report findings severity-ordered with file:line

## Output format

```
Findings (severity-ordered with file:line)
Risk surfaces touched
Tests reviewed: yes / no — verdict
Recommendation: APPROVED | APPROVED-WITH-NITS | REJECTED — <reason>
```

## Hard stops

- High-risk surface diff with no adversarial review → stop, route to `security-engineer` first
- Reviewer is the author of the change → stop, fresh reviewer required
- "Tests pass" offered as the only review evidence → not a review; do the axis walk

## Full Rolepod enhancement

Full Rolepod improves this phase by adding the qa-tester floor, external adversarial CLI reviewers (Codex / Gemini) routed by risk, hooks that block subagent commits, and the two-stage fresh-context review pattern for delegated work.

## Next phase

- If `finish-work` is available, continue there for the merge gate.
- If `finish-work` is not available, present the findings + recommendation to the user and ask which finish path they want.
