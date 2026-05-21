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

## 10. Sub-agent commit ban (HARD RULE)

Sub-agents NEVER run `git commit`, `git push`, `gh pr merge`, `gh pr create`, `git reset --hard`, or `git push --force` directly. Lead owns version-control state after qa-tester + universal-reviewer verify pass.

Sub-agent done → return COMPLETED + file list + verification evidence (test pass output / lint clean / typecheck clean). Lead reads, runs review gate, commits.

Enforced via PreToolUse Bash hook (`hooks/block-subagent-commit.sh`) — Claude Code's hook input has `agent_id` field populated only for sub-agent calls. Hook denies with `permissionDecision: deny` + reason; agent sees hard stop, NOT advisory warning.

Why this rule exists: real-world failure observed where a backend-developer sub-agent committed after marking COMPLETED + tsc=0, bypassing the qa-tester floor entirely. Soft reminder hooks were already in place but ignored under "success cue" flow-state. Hard block via permission deny is the only mechanism that survives flow-state drift.

**Scope:** the rule itself applies universally; the hook-based enforcement is currently Claude Code only. Codex CLI's PreToolUse hook input exposes no caller identity — there is no `agent_id` or sub-agent field (confirmed against the Codex hooks docs), so Lead vs sub-agent cannot be distinguished; Codex plugin-bundled hooks are also opt-in via `[features].plugin_hooks`. Gemini CLI hook event model differs (no Agent matcher). On Codex/Gemini the rule relies on Lead self-discipline reading AGENTS.md / GEMINI.md until upstream parity exists.

## 11. Discipline gates — high-risk path enforcement (Claude scope)

Three additional PreToolUse blocks fire on Claude Code only (same scope limit as rule 10):

- `gate-reminder.sh` denies on a high-risk path Edit when the session has 0 test edits (RED-test discipline) or ≥2 high-risk edits with 0 reviewer agents dispatched (qa-tester / security-engineer / universal-reviewer floor).
- `precommit-gate.sh` escalates to HARD block at `git commit` time when the session touched high-risk code but never produced a test edit, even if the final diff looks small.
- `cohesion-contract-check.sh` denies a 2nd+ engineering Agent spawn within 10 events when no `contract.md` / `SPEC.md` / `cohesion.md` / `specs/*.md` was written this session (skill `write-plan`).

Bypass envs for one-off legit cases: `ROLEPOD_GATES_SOFT=1` (downgrade hard → warn), `ROLEPOD_GATES_PASSED=1` (single-edit override), `ROLEPOD_NO_CONTRACT=1` (single-domain Agent spawn).

High-risk path = path segment match on auth / authn / authz / billing / payment(s) / migration(s) / credit(s) / permission(s) / secret(s) / crypto / cryptography / token(s) / oauth / jwt / sso / saml / webhook(s) / stripe / paypal / charge(s) / invoice(s). Anchored to path segments (`/`, `.`, `_`, start/end), not substrings — avoids false positives like `session_state.py`.
