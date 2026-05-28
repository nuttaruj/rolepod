<!-- Author-side deep playbook for processing review findings. -->
<!-- Loaded on demand from review-code/SKILL.md §6. -->
<!-- Reviewer-side doctrine lives in SKILL.md; this file is for the author. -->

# Receiving findings

When findings come back from a reviewer (subagent, external CLI, human PR comment), the author's behavior decides whether the fix lands clean or creates a new bug class.

## Forbidden phrases — full catalog

Gratitude / performative agreement corrupts the response loop. The reader is a model; it does not need affirmation. Words add tokens and noise; the patched diff is the answer.

| Phrase | Why it is forbidden | Use instead |
|---|---|---|
| "You're absolutely right!" | Performative agreement before verification → skips the VERIFY step | "Verified — implementing." |
| "Great point!" | Same — agreement without evaluation | Just state the fix |
| "Excellent feedback!" | Same | Show the patch |
| "Thanks for catching that!" | Gratitude adds no signal | "Fixed in <file:line>." |
| "Let me implement that now" | Action statement without evaluation → invites blind impl | First state what was wrong, then fix |
| "Good question!" | Defers thinking | Answer the question |
| Any sentence starting with "Thanks" | Filler | Delete it; state the fix |

**Self-check rule.** If a response starts with thanks, "great", "absolutely", or "excellent" — delete and rewrite. State the fix or ask the clarifying question.

## Source-specific handling

### From the user (Lead-trusted)

- Implement after understanding — scope unclear → ask
- No performative agreement
- Just act, or give a one-line technical acknowledgment ("Verified — fixing X")

### From an external reviewer (subagent or another CLI)

Before implementing **any** suggestion, run this 5-check:

1. **Correct for THIS codebase?** — the reviewer may be reasoning from generic patterns; check the repo's actual conventions
2. **Breaks existing functionality?** — grep for callers / tests that rely on the current shape
3. **Reason for current implementation?** — `git blame` + commit message; the current shape may exist for a reason the reviewer missed
4. **Cross-platform / cross-version?** — the suggestion may assume a runtime version the project does not commit to
5. **Reviewer has full context?** — if the brief was narrow, the suggestion may not see the constraint that matters

If any check fails → push back with technical reasoning before implementing.

### When the finding conflicts with a prior user decision

Stop. Do not implement. Escalate: "Reviewer flagged X; this contradicts the decision on <date / commit>. Want to reverse or hold?"

The reviewer outranks neither documented decisions nor user direction.

## YAGNI check on additive findings

When the reviewer says "implement properly", "add complete X handling", or "this should support Y too":

```bash
rg "<the-thing-the-reviewer-wants-added>" <project-paths>
```

- **Unused** → propose removing the surface (YAGNI) instead of building more
- **Used in 1 place** → ask whether the use case needs the extension, or whether the single caller is the real scope
- **Used widely** → implement properly

Rationale: the reviewer can ask for completeness; the author owns scope. Both report to the user. If the surface is dead, deleting it is the right fix to a completeness finding.

## Pushback playbook

### When to push back

- Suggestion breaks an existing test
- Reviewer lacks codebase context (e.g., does not know the surface is internal-only)
- YAGNI violation on an unused or one-call surface
- Wrong for the stack / runtime / version target
- Legacy / compatibility constraint the reviewer did not see
- Conflicts with a documented architecture decision from the user

### How to push back

- Technical reasoning, not defensive tone
- Specific question, not generic disagreement
- Reference a working test, file path, or commit
- Keep it short — one or two sentences; let the link / test do the talking

Good: "`tests/auth_spec.rb:42` asserts the current shape; the suggested rewrite would fail this. The current impl exists to support the SAML path."

Bad: "I don't think that's right; we should keep the current code because it's been working."

### Correcting wrong pushback

If you pushed back, the reviewer rebutted, and the reviewer is right:

Good: "You were right — checked `<file:line>`; the current impl does fail on `<case>`. Fixing."

Bad: long apology / over-explanation / defending why you pushed back. State the correction and move on.

## Implementation order for multi-finding

When ≥3 findings land at once:

1. **Read all** — do not start implementing while still reading
2. **Clarify all unclear** — never partial-implement when items may be linked
3. **Order by class:**
   - Blocking (security / data loss / breaks build) → fix first
   - Simple (typo / import / rename / dead code) → batch second
   - Complex (refactor / logic / new abstraction) → last, one at a time
4. **Test each individually** — do not batch the test pass; a regression in one obscures the others
5. **Verify no regressions in upstream features** — touched-files end-to-end, not just the changed lines

## GitHub thread replies

When replying to an inline review comment on a PR, reply **in the thread** so the discussion stays attached to the line:

```bash
gh api repos/{owner}/{repo}/pulls/{pr}/comments/{id}/replies \
  --method POST \
  -f body="<reply>"
```

A top-level PR comment fragments the conversation and the reviewer's context. Use top-level only for summary statements ("Addressed all findings — please re-review").

## Common mistakes

| Mistake | Why it bites | Fix |
|---|---|---|
| Performative agreement before verifying | Reader takes it as confirmation → skip VERIFY → blind impl | Delete the agreement; restate the requirement |
| Batch-implement without testing each | Regression in finding 2 hides under finding 5's diff | Test each, commit each |
| Assume the reviewer is right | Reviewer may be reasoning from generic patterns | Run the 5-check above |
| Avoid pushback to be agreeable | Wrong fix lands; bug compounds | Tech rigor over comfort |
| Implement only the items you understood | Findings linked; partial = wrong | Clarify all first |
| "Can't verify, proceed anyway" | Lands a guess | State the limitation, ask for direction |
| Gratitude at end of response | Pure noise; bloats output | Delete |

## The bottom line

External feedback is suggestions to evaluate, not orders to follow. Verify. Question. Then implement.

No performative agreement. Technical rigor always.
