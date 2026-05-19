# Legacy Skill Map

Rolepod used to ship many small executable skills. Those have been consolidated into Core 10. This file keeps the migration map as prose only; these names are **not** installed as `core/skills/<name>/` directories anymore.

Use this table when updating old docs, prompts, or agent memories.

| Old skill name | Canonical Core 10 route | What moved |
|---|---|---|
| `spec-driven-development` | `write-spec` | Spec / discovery / scoping |
| `doc-coauthoring` | `write-spec` | Interview-style doc/spec shaping |
| `planning-and-task-breakdown` | `write-plan` | Ordered tasks + test plan |
| `team-routing` | `write-plan` | Agent choice and routing |
| `parallel-contract-orchestration` | `write-plan` | Cohesion contract before parallel work |
| `api-and-interface-design` | `write-plan` | API / interface / module boundary design |
| `source-driven-development` | `write-plan` | Official-doc grounding for platform decisions |
| `subagent-task-execution` | `implement-plan` | Bounded delegation + fresh reviewer |
| `test-driven-development` | `implement-plan` | Red → green → refactor discipline |
| `using-worktrees` | `implement-plan` | Worktree discipline during implementation |
| `frontend-ui-engineering` | `implement-plan` | Frontend implementation workflow |
| `interface-design` | `implement-plan` | Dashboard/admin/tool interface work |
| `interaction-design` | `implement-plan` | Motion, microinteractions, feedback |
| `claude-api` | `implement-plan` | Claude / Anthropic SDK implementation |
| `seo` | `implement-plan` | SEO implementation and content workflow |
| `documentation-and-adrs` | `implement-plan` | Durable docs / ADR production |
| `user-facing-content` | `implement-plan` | FAQs, errors, onboarding, empty states |
| `internal-comms` | `implement-plan` | Status updates, memos, announcements |
| `conversion-copywriting` | `implement-plan` | Landing-page / campaign copy |
| `systematic-debugging` | `debug-issue` | Reproduce → trace → test → fix |
| `debugging-and-error-recovery` | `debug-issue` | Broken behavior recovery |
| `root-cause-tracing` | `debug-issue` | Upstream causal tracing |
| `post-change-verify` | `check-work` | Evidence before completion claim |
| `webapp-testing` | `check-work` | Playwright-style UI verification |
| `browser-testing-with-devtools` | `check-work` | Live browser / console / network checks |
| `code-review-and-quality` | `review-code` | Multi-axis code review |
| `reviewer-flow` | `review-code` | Reviewer routing |
| `doubt-driven-development` | `review-code` | Adversarial fresh-context review |
| `web-design-guidelines` | `review-code` | UI/a11y/design-quality review |
| `security-and-hardening` | `review-code` | Security review and hardening |
| `performance-optimization` | `review-code` | Performance review and perf-risk routing |
| `pre-merge-gate` | `finish-work` | Simplicity/test/reviewer gate before merge |
| `finishing-a-development-branch` | `finish-work` | 4-option branch finish menu |
| `shipping-and-launch` | `finish-work` | Launch / monitoring / rollback checklist |
| `ci-cd-and-automation` | `finish-work` | CI/CD lane discipline |
| `code-simplification` | `simplify-code` | Behavior-preserving cleanup |
| `anti-spaghetti` | `simplify-code` | Duplication / dead code / drift cleanup |
| `context-engineering` | `manage-context` | Context budget and load discipline |
| `session-hygiene` | `manage-context` | Restart, compact, resume, task switch |
| `zoom-out` | `manage-context` | Meta-cognitive recovery from drift |
| `triage-deep` | `manage-context` | Multi-file triage / scope recovery |
| `advisor-escalation` | `manage-context` | Escalating stuck sessions |
| `new-project-onboarding` | `manage-context` | Unfamiliar repo onboarding |

## Compatibility policy

- Do not re-add executable compatibility shims unless a real install break is proven.
- If a legacy phrase stops routing correctly, update the matching Core 10 `description:` / `when_to_use:` instead of adding a new skill.
- If a domain workflow is large enough to deserve its own public skill, it must pass the skill-design bar in [skills.md](skills.md) and stay useful when copied alone.
