# Agent Protocol — shared across all subagents

**Scope:** mandatory rules every subagent follows. Referenced via "follow agent-protocol".

## 1. Verify-first

- Symbol/file exists? Read or `gitnexus_context` first
- Behavior? Run actual command
- External fact (API/pricing/lib)? WebFetch/WebSearch
- Past decision? `mempalace_kg_query` + verify code matches

Pattern-match alone = forbidden. Can't verify → state `Assuming: X. Risk: Y. Verify by: Z`.

## 2. Tech-agnostic detection

Detect project tech via Read on config files (`package.json` / `pyproject.toml` / `Cargo.toml` / `Makefile` / etc.). Match existing patterns. Don't introduce new "because better."

## 3. Completion verification

1. **Verify edits exist** — Grep/Read each file claimed changed
2. **Run project checks** — test/lint/typecheck
3. **Check silent failures** — DB column → migration includes it. API field → schema + response. File created → exists.
4. **Never claim done with failing checks** — fix or report incomplete
5. **Missing target** — STOP, report `MISSING TARGET: [what] at [where]`. Never silently skip.

## 4. Autonomous error handling

- Never blind edit — Read/Grep first
- Command fails → analyze, retry max 2x, then escalate
- Empty/malformed result → diagnose, don't assume it worked
- Migration/schema/model empty diff → report explicitly

## 5. Hand-off protocol

1. **Files** — exact paths modified
2. **Summary** — done + what next agent must do
3. **Upstream check** — confirm prereqs exist before starting
4. **API/schema changes** — old vs new + downstream impact
5. **Breaking** — prefix `BREAKING:`
6. **Downstream deps** — name next agent(s)

## 6. Mandatory peer review

Cannot complete alone. Request review from `universal-reviewer` (or domain reviewer). Fix rejected issues.

Exception: `universal-reviewer` = final judge, cannot review its own feedback.

## 7. Change manifest

```
**Changes Made:**
- `[file]`: [what changed] (verified: yes/no)

**Verification:**
- Tests: [pass / fail / none found]
- Lint/Type-check: [pass / fail / none found]
- Domain-specific: [as applicable]

**Status:** COMPLETED | PARTIAL | BLOCKED
- PARTIAL: list remains + why
- BLOCKED: state blocker + who unblocks
```

Never COMPLETED if anything unverified.

## 8. Memory

Update agent memory with codepaths discovered, patterns, library locations, architectural decisions. Concise — what + where.

## 9. Scope discipline

- Own ONE domain (defined in agent file)
- Don't touch other agents' domains — hand off
- Same path/concern conflict → STOP, ask Lead
