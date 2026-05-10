# Agent Protocol — shared across all subagents

**Scope:** mandatory rules every subagent follows. Referenced by all agent files via "follow agent-protocol".

## 1. Verify-first (before any claim)

- Symbol/file exists? Read or `gitnexus_context` first
- Behavior? Run actual command, don't assume
- External fact (API/pricing/lib version)? WebFetch/WebSearch
- Past decision? `mempalace_kg_query` + verify code matches

Pattern-match alone = forbidden. Can't verify → state `Assuming: X. Risk: Y. Verify by: Z`.

## 2. Tech-agnostic detection

Before writing code, detect project tech via Read on config files (package.json / pyproject.toml / Cargo.toml / Makefile / etc.). Match existing patterns. Don't introduce new patterns "because better."

## 3. Completion verification (before reporting done)

1. **Verify edits exist** — Grep/Read each file you claim to have changed
2. **Run project checks** — find available test/lint/typecheck commands, run them
3. **Check silent failures** — DB column added → migration includes it. API field → schema + response. File created → exists.
4. **Never claim done with failing checks** — fix or report incomplete
5. **Missing target** — STOP and report `MISSING TARGET: [what] at [where]`. Never silently skip.

## 4. Autonomous error handling

- Never blind edit — Read/Grep first
- Command fails → analyze, retry max 2x, then escalate
- Empty/malformed result → diagnose root cause, don't assume it worked
- Migration/schema/model produces empty diff → report explicitly

## 5. Hand-off protocol

When handing off to another agent:
1. **Files** — exact paths modified
2. **Summary** — what done + what next agent must do
3. **Upstream check** — confirm prerequisite files/APIs/schemas exist before starting
4. **API/schema changes** — list old vs new + downstream impact
5. **Breaking changes** — prefix `BREAKING:`
6. **Downstream deps** — name agent(s) that act next

## 6. Mandatory peer review

Cannot complete alone. Must request review from `universal-reviewer` (or domain-specific reviewer). Fix rejected issues.

Exception: `universal-reviewer` itself = final judge. Cannot request review for its own feedback.

## 7. Change manifest output (every task ends with)

```
**Changes Made:**
- `[file path]`: [what changed] (verified: yes/no)

**Verification:**
- Tests: [pass / fail / none found]
- Lint/Type-check: [pass / fail / none found]
- Domain-specific check: [as applicable]

**Status:** COMPLETED | PARTIAL | BLOCKED
- PARTIAL: list what remains + why
- BLOCKED: state blocker + who must unblock
```

Never report COMPLETED if anything unverified.

## 8. Memory / institutional knowledge

Update agent memory with: codepaths discovered, patterns, library locations, architectural decisions. Concise notes — what found + where.

## 9. Scope discipline

- You own ONE domain (defined in your agent file)
- You DO NOT touch other agents' domains — escalate via hand-off
- Same path/concern conflict with another agent → STOP, ask Lead to resolve
