# 18-Agent Standalone Audit (post PR 2)

Purpose: snapshot of agent files after the Core 10 consolidation (PR 1) and the standalone hardening (PR 2). Every agent file is now usable when copied alone — labeled sections, output contract, escalation back to Core 10 — and references no legacy shim names in its `skills:` preload.

## Standalone contract (spec line 708-722, enforced by lean-surface)

Every agent file includes:

```
Role identity                — frontmatter
When to use                  — ## When to use
Inputs it needs              — ## Inputs to request from Lead
What it must inspect         — ## What to inspect first
Path / concern ownership     — ## OWN / DO NOT touch
Domain expertise             — ## Domain expertise (5-10 checks)
Hard stops                   — ## Hard stops (or ## Final authority for gate agents)
Output contract              — ## Output contract (or ## Final authority for gate agents)
When to ask Lead             — ## When to ask Lead
Hand-off                     — ## Hand-off (matrix to other agents)
Escalation back to Core 10   — ## Escalation back to Core 10
```

Forbidden language (none in current source):

- `Requires <skill>` / `Requires Rolepod skills` / `Only works inside full Rolepod install`
- `Ask Lead to load <skill> before proceeding`

`skills:` preload must be a subset of Core 10 — verified by static check.

## Per-agent verdict (post PR 2)

| Agent | Status | `skills:` preload | Notes |
|-------|--------|-------------------|-------|
| `ai-ml-engineer` | **pass** | implement-plan, write-plan | Sections + output contract + escalation added; existing Verify-first / Completion verification preserved |
| `backend-developer` | **pass** | write-plan, implement-plan, simplify-code | Sections added; high-risk-surface awareness added in Hard stops |
| `billing-engineer` | **pass** | review-code, implement-plan | High-risk surface kept; race + idempotency + audit-log gates now explicit Hard stops |
| `business-analyst` | **pass** | write-spec | Sections added; Verify-first for competitor pricing preserved |
| `customer-success` | **pass** | implement-plan | Voice-rule + jargon-ban kept; sections added |
| `data-scientist` | **pass** | write-spec, write-plan | Iron Law preserved; sections + output contract added |
| `devops-sre` | **pass** | finish-work | CI lane responsibilities preserved; release-plan output contract added |
| `frontend-developer` | **pass** | implement-plan, simplify-code | Sections added; auth-token / double-submit Hard stops added |
| `growth-marketer` | **pass** | implement-plan | Verify-first preserved; technical-SEO out-of-scope reaffirmed |
| `mobile-developer` | **pass** | implement-plan | iOS + Android + RN + Flutter scope kept; app-store-rejection Hard stops added |
| `performance-engineer` | **pass** | review-code, check-work | Mandatory measure-optimize-verify loop preserved; baseline-missing Hard stop emphasized |
| `product-manager` | **pass** | write-spec, write-plan | Spec template preserved; placeholder / "should" / "maybe" Hard stops added |
| `qa-tester` | **pass** | review-code, check-work, implement-plan, debug-issue | Dual-mode + Final authority preserved; Hard stops added |
| `security-engineer` | **pass** | review-code | Mandatory invocation triggers + Final authority preserved; CRITICAL / HIGH / MEDIUM / LOW severity kept |
| `system-architect` | **pass** | write-plan, write-spec | Pre-engineering deliverables preserved; alternatives-required Hard stop made explicit |
| `tech-writer` | **pass** | write-spec, implement-plan | Comment policy preserved; placeholder + rollback-path Hard stops added |
| `ui-ux-designer` | **pass** | implement-plan, review-code | A11y mandatory checks preserved; WCAG-AA + focus + reduced-motion Hard stops |
| `universal-reviewer` | **pass** | review-code, simplify-code | Pure-review tool restriction preserved; Final authority output kept |

## Summary

| Status | Count | Notes |
|--------|------:|-------|
| **pass** | 18 | All agents include labeled sections + output contract + escalation back to Core 10 |
| **needs-hardening** | 0 | All cleared in PR 2 |
| **broken** | 0 | None in PR 1 or PR 2 |

`skills:` preload audit:
- 0 agents reference a Tier 3 compatibility shim
- 18 agents reference only Core 10 skill names

Forbidden-language scan: 0 hits across all 18 files.

## Standalone usefulness targets (spec line 558-562)

| Install mode | Target | Actual |
|--------------|------:|--------|
| Copy one agent alone | ~80% | Reached — each agent now carries inputs, hard stops, output contract, escalation path |
| Copy one Core 10 skill alone | 70-80% | Already achieved in PR 1 |
| Copy one Core 10 skill + matching agent | 85-90% | Achieved — both artifacts work standalone and compound when paired |
| Full Rolepod install | 100% | Best experience: router + hooks + tests + cost-aware routing all connected |

## When the standalone contract re-fires

- **Every release:** re-run this audit.
- **New agent added:** must classify as **pass** at landing time (labeled sections from day one, `skills:` preload subset of Core 10).
- **Agent file > 200 lines:** review for bloat — agent expertise is concise checklists, not full domain manuals. The Core 10 phase skill owns workflow; the agent owns deep expertise within that phase.
- **Legacy shim referenced as the active route:** the lean-surface check flags any active route through legacy names. Compatibility-context mentions (eg "legacy `team-routing` shim redirects here") are allowed; active routing is not.

## What still defers to a future release

- **Release N+1 shim removal:** the 43 Tier 3 compatibility shims remain in place for one migration release. Once behavior tests confirm the Core 10 route catches every legacy trigger phrase in production usage, the shims may be deleted or moved to `docs/legacy-skills.md`.
- **`check-security` optional Tier 2:** not shipped in PR 1 or PR 2. Add only if product direction confirms users want an explicit public security workflow (otherwise security routes through `review-code` + `security-engineer`).
