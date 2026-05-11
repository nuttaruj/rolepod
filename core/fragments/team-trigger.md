## Team workflow trigger

Default Lead pattern = Subagent + Task spawn (current behavior, covers 80%+ tasks).

### Two opt-in patterns

**1. Full-lifecycle team (broad trigger)**

User says: "use team" / "use team workflow" / "as a team" / "big feature, team" / "team workflow" / "with team" / "use teams"

Lead behavior: ALL 6 phases use team recipes
- `/team-define` → `/team-plan` → `/team-build` → `/team-verify` → `/team-review` → `/team-ship`
- Each phase = multi-agent coordinated dispatch
- Auto-progress phase-by-phase
- Cost: high (5-10x token vs default Subagent)
- When: big feature delivery, end-to-end max effort

**2. Surgical team (slash command)**

User runs: `/team-build` (or any specific `/team-<phase>`)

Lead behavior: ONLY specified phase uses team; rest use default Subagent
- e.g. `/team-build` → Build phase = team recipe, but Define / Plan / Verify / Review / Ship = default Subagent
- User picks WHERE to invest extra coordination
- Cost: medium (focused on 1 phase)
- When: max effort on specific phase, default elsewhere

User can mix multiple slash commands per task (e.g. `/team-build` + `/team-review`) — only those phases switch to team mode.

### 6 lifecycle recipes (used by both patterns)

**team-define** — frame intent → spec
- Spawn: `product-manager` (user stories) + `business-analyst` (ROI) + `system-architect` (feasibility)
- Output: `SPEC.md`
- Gate focus: verify-first (intent verification)

**team-plan** — spec → ordered tasks + cohesion contract
- Spawn: `system-architect` (writes contract + RED tests) + `product-manager` (task breakdown)
- Specialists joined by path: `billing-engineer` / `ai-ml-engineer` / `security-engineer` when relevant
- Output: `contract.md` + RED tests + task list
- Gate focus: Q1-Q4 delegation

**team-build** — tasks → code (parallel-safe by path)
- Spawn parallel: engineers by path (backend / frontend / mobile / billing / ai-ml / data) via cohesion contract
- Owner: `system-architect` (contract enforcer)
- Cycle: RED → GREEN → REFACTOR per task
- Gate focus: S1-S5 simplicity, F1-F6 failure-mode

**team-verify** — code → evidence
- Spawn: `qa-tester` (universal floor) + `security-engineer` (auth/billing) + `performance-engineer` (perf-sensitive)
- Gate focus: T1-T6 testing, verify-first

**team-review** — evidence → adversarial pass
- Spawn: `universal-reviewer` + `qa-tester` (review-mode)
- Adversarial: doubt-driven-development cycle (bounded 3)
- Gate focus: pre-merge-gate

**team-ship** — approved → deploy + announce
- Spawn: `devops-sre` (deploy) + `tech-writer` (release notes) + `growth-marketer` (announce) + `customer-success` (FAQ)
- Gate focus: CI 3-phase

### Mandatory gates apply to both patterns

Regardless of pattern (default Subagent / broad team / surgical team):
- T1-T6 (testing) — must run before commit
- S1-S5 (simplicity) — must run before commit
- F1-F6 (failure-mode) — must run before declare done
- pre-merge-gate — must run before merge
- CI 3-phase — must pass before auto-merge

Team or Subagent = orchestration pattern, NOT gate skip.

### Lead behavior

When team trigger fires:
1. Acknowledge team mode active to user (which pattern + which phase(s))
2. Detect scope: vague feature → start `/team-define`; specific phase → that team; multi-phase → orchestrate sequence
3. Run phase recipe — spawn agents per recipe + cohesion contract where applicable
4. Persist context across phases (Lead's own session context carries forward)
5. CEO reviews output (same as default)

### When NOT to use Team (default Subagent is right)

- Single-file fix / typo / quick refactor
- Tasks needing <3 agents
- Independent investigations (qa OR security OR perf alone, not all 3)
- Lead's Q1-Q4 routing handles it cleanly
- Time-sensitive hotfix (recipe overhead > value)

Reference: https://code.claude.com/docs/en/agent-teams (Lead-orchestrated; YAML team configs are runtime-managed by Anthropic — rolepod ships recipes only, no pre-authored team schemas).
