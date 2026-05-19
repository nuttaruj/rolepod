# 18-Agent Standalone Audit (PR 1 — Core 10 consolidation)

Purpose: per spec acceptance criterion #11, PR 1 must include an audit confirming every shipped agent works when copied alone (no Rolepod skills installed). This file is the audit record. PR 1 modifies an agent only when it currently blocks standalone safety, docs render, or tests; deeper hardening defers to PR 2.

## Standalone contract (spec line 708-722)

Every agent file should include:

```
Role identity
When to use
Inputs it needs
What it owns
What it does not own
5-10 domain checks
Hard stops
Verification expectations
Output format
When to ask the user or Lead
```

Forbidden language (anywhere in agent file):

- `Requires <skill>` / `Requires Rolepod skills` / `Only works inside full Rolepod install`
- `Ask Lead to load <skill> before proceeding`

## Audit method

For each of the 18 agents:

1. Read the full agent file.
2. Map present / missing sections against the standalone contract.
3. Confirm no forbidden language appears (`grep` across all 18 agents returned zero hits).
4. Classify:
   - **pass** — covers contract well enough to act standalone.
   - **needs-hardening** — usable, but missing one or more sections that would help a copy-only user. Soft fail — no test or docs blocker.
   - **broken** — would fail to act standalone OR contains forbidden hard-dependency language. Hard fail — must fix in PR 1.

5. Determine PR 1 action: modify only if classified `broken`. Defer all `needs-hardening` to PR 2.

## Per-agent verdict

| Agent | Status | Missing sections (vs contract) | PR 2 action | Modified in PR 1 |
|-------|--------|--------------------------------|-------------|------------------|
| `ai-ml-engineer` | needs-hardening | When to use (explicit), Inputs, Hard stops, Output format, When to ask Lead | Add labeled sections; preserve current Anthropic-SDK / prompt-cache depth | no |
| `backend-developer` | needs-hardening | When to use, Inputs, Hard stops, Output format, When to ask Lead | Add labeled sections; current Path ownership + Domain expertise are strong | no |
| `billing-engineer` | needs-hardening | When to use, Inputs, Hard stops, Output format | Add labeled sections; high-risk path so output format should include `APPROVED / REJECTED + risk` pattern | no |
| `business-analyst` | needs-hardening | When to use, Inputs, Hard stops, Output format, When to ask Lead | Add labeled sections; preserve Verify-first list for pricing / market data | no |
| `customer-success` | needs-hardening | When to use, Inputs, Hard stops, Output format, When to ask Lead | Add labeled sections | no |
| `data-scientist` | needs-hardening | When to use (explicit), Hard stops, Output format | Strongest agent file already; mostly needs explicit section headings, not new content | no |
| `devops-sre` | needs-hardening | When to use, Inputs, Hard stops, Output format, When to ask Lead | Add labeled sections; include rollback / monitoring expectations in output format | no |
| `frontend-developer` | needs-hardening | When to use, Inputs, Hard stops, Output format, When to ask Lead | Add labeled sections; Path ownership + Domain expertise are clear | no |
| `growth-marketer` | needs-hardening | When to use, Inputs, Hard stops, Output format, When to ask Lead | Add labeled sections | no |
| `mobile-developer` | needs-hardening | When to use, Inputs, Hard stops, Output format, When to ask Lead | Add labeled sections | no |
| `performance-engineer` | needs-hardening | When to use (explicit), Hard stops, Output format | Mostly section headings; existing content is dense and good | no |
| `product-manager` | needs-hardening | When to use, Inputs, Hard stops, Output format, When to ask Lead | Add labeled sections | no |
| `qa-tester` | **pass** | When to use, Inputs (minor) | None blocking — already has dual-mode brief, hand-off, final-authority output (`APPROVED / REJECTED`), explicit invocation triggers, mandatory rules link | no |
| `security-engineer` | **pass** | When to use, Inputs (minor) | None blocking — already has mandatory invocation triggers, verify-first, hand-off, `APPROVED / REJECTED` output with severity, mandatory rules link | no |
| `system-architect` | needs-hardening | When to use, Inputs, Hard stops, Output format | Add labeled sections; preserve current Path / Decision ownership content | no |
| `tech-writer` | needs-hardening | When to use, Inputs, Hard stops, Output format, When to ask Lead | Add labeled sections | no |
| `ui-ux-designer` | needs-hardening | When to use, Inputs, Hard stops, Output format, When to ask Lead | Add labeled sections | no |
| `universal-reviewer` | **pass** | When to use, Inputs (minor) | None blocking — already has scope, severity rubric, hand-off, `APPROVED / REJECTED` output, mandatory rules link | no |

## Summary

| Status | Count | Action in PR 1 |
|--------|------:|----------------|
| **pass** | 3 (qa-tester, security-engineer, universal-reviewer) | none — agents already standalone |
| **needs-hardening** | 15 | none — deferred to PR 2 |
| **broken** | 0 | n/a |

No agent contains forbidden hard-dependency language (`Requires <skill>`, `Only works inside full Rolepod`, `Ask Lead to load <skill>`). All 18 agents preserve their role identity, ownership boundaries, domain expertise list, and hand-off matrix when copied alone.

## PR 2 hardening template

For each `needs-hardening` agent, add labeled sections without rewriting existing content:

```md
## When to use
- <trigger phrase 1>
- <trigger phrase 2>

## Inputs it needs
- <what Lead must supply in the brief>

## Hard stops
- <condition that blocks continuing — stop, escalate>

## Output format
- <fields the agent's response must include>

## When to ask Lead
- <ambiguity / missing context conditions>
```

Preserve existing sections (Domain expertise, Path/Concern ownership, Hand-off, Mandatory rules). Cap each new section at 5-10 lines.

## Why defer to PR 2

PR 1 scope guard (verdict #6): "Do not rewrite all 18 agents in PR 1. Audit all 18. Modify an agent only if it currently blocks standalone safety, docs render, or tests." None of the 15 `needs-hardening` agents fail tests, break docs render, or contain forbidden hard-dependency language. All 18 still function standalone — the missing section labels are usability improvements, not safety blockers.

Deep agent rewrite happens in PR 2 (Release N+2 per the migration policy) alongside the agent-instruction distillation that absorbs the deep domain expertise that used to live in shimmed standalone skills.

## Re-audit cadence

- Every release: re-run this audit.
- Any new agent added: must classify as **pass** at landing time (label sections from day one).
- Any agent file >120 lines: review for bloat — concise checklists, not full playbooks (per spec line 859-866).
