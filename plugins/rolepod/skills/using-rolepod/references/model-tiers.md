<!-- Load when delegating work, picking a model class, or running a fleet. -->

# Model tiers and fleets

Tiers are classes, never model names. Map them once onto the models the user has opted into (this CLI's always-on names them; never a full aggregator catalog). A model you cannot classify → balanced, and say so.

### Portable role dispatch

A role defines responsibilities and instructions; an agent type is CLI transport. Prefer the CLI's native named role when available. If custom roles are unavailable but a default/general subagent exists, dispatch a fresh isolated child with the same rendered role instructions and bounded task brief. Read only the needed role from an accessible rendered or installed file, including its shared protocol when present; never forward unresolved `INCLUDE` directives.
If role instructions are unavailable, report the missing role and use a fallback explicitly defined for that condition; otherwise report BLOCKED. Missing role text does not mean custom roles are unavailable. Carry model, effort, tool limits, read/write scope and no-commit rule through controls the CLI exposes. Unsupported controls remain instruction-level limits, reported as limitations; never invent tool fields or claim mechanical enforcement.
A prompt role name is not native dispatch metadata or hook evidence. Keep reviewer floors and report provenance; if a mechanical gate cannot recognize the fallback, report that limitation and keep the gate blocked without a user waiver. With no subagent facility, the Lead follows the existing skill loop. Reviewer independence, mode-specific floors and no-agent limitations still follow `convening-code-review`.

| Class | The set's… | Work |
|---|---|---|
| **cheap** | small / fast model | docs, copy, read-only sweeps, mechanical builds, flow runs, command-settled checks |
| **balanced** | mid flagship | ALL implementation, high-risk paths included — the net is the strong review floor, never the writer's tier |
| **strong** | top reasoning model | architecture, final-pass and adversarial review. A set whose top sits below frontier-class still gets the full review; the depth cap is a recorded LIMITATION |
| **apex** | strongest tier the CLI exposes | the adversarial pass only: an irreversible change with no rollback (destructive migration, key rotation, live money movement), a novel design with no pattern to diff against, deep cross-system reasoning (races on financial invariants, distributed consistency), or a user ask; a CLI whose strong pin is its ceiling collapses apex into strong; a costlier rung is a cost decision, so surface it first; the dispatch line's `override` records the rung sent |

Skills by class:
- cheap — vague build / doc / UI asks and repeat or legacy features (`write-spec`), prototypes, `manage-context` and its handoff briefs, explain-only answers, release notes and changelogs.
- cheap — every `domain: writing` task, not only pure copy.
- cheap — a mechanical build task: a rename, config, wiring, a render or pin update, a change that copies an existing pattern; no new logic and no new test.
- cheap — the flow run of the QA pass (open, click, observe, report); a new E2E test stays balanced.
- cheap — a per-item verify a command or grep settles, at high effort; a judgment call stays balanced.
- A cheap row never builds or verifies a high-risk path, and a cheap task returned rejected or `BLOCKED` twice goes balanced.
- cheap to balanced — `write-plan` against an existing spec.
- balanced — executing a plan's logic tasks, multi-agent planning, `debug-issue` fixes, `simplify-code`, perf, UI and infra builds, `check-work`, high-risk builds, a new E2E test, the lens review and its Fix-verify re-check (`rolepod-reviewer`).
- strong — high-risk review (`rolepod-reviewer` `lens: security` / `lens: adversarial`), architecture, the ONE final branch review of a multi-track plan (`orchestrating-plans` step 6), `deepen-codebase` (explorer tier: its step 2).

The Lead picks the class at dispatch; escalate on a BLOCKED redispatch, a user ask, or the same agent failing its task twice (the next dispatch one tier up, strong at most).

## Keep a strong row strong

- A strong row passes a strong-class model on the call; no rolepod type pins strong.
- A spawn with no pin inherits the Lead. Under a balanced or cheap Lead that is a silent downgrade, so pass an explicit strong-class override on that ONE call, never on a fan-out.
- A downgraded strong role is not the strong slot. `rolepod-reviewer` runs balanced on every CLI, except the ONE final branch review of a multi-track plan (`orchestrating-plans` step 6): one fresh strong `rolepod-reviewer` via the one-call strong override above. A `rolepod-reviewer` with `lens: security` or `lens: adversarial` gets a strong-class model on the call. The commit gate checks for a security lens report, any model, not the tier.

## Fleets

- One strong slot per fleet: sweep = cheap · mechanical build = cheap · logic build = balanced · per-item verify = cheap at high effort when a command settles it, else balanced at high effort · the ONE judge or security reviewer = strong.
- Never inherit the Lead's model across a fleet (one exception: several plans at once → `write-plan` `references/edge-cases.md`); never pin strong on a fan-out (price × N).
- A stage that writes uses the role's instructions. Prefer the CLI's native named role; portable transport and Lead fallback are defined above. A fan-out uses the role's model tier where the CLI exposes that control.
- Mechanics live in your CLI's `references/fanout-<cli>.md` (Claude: `fanout-claude.md`, Codex: `fanout-codex.md`); no file for your CLI → dispatch roles one at a time.

**Retry-at-higher-effort (checkable stages).** When a stage's outcome is
mechanically checkable (tests, verifier, schema), dispatch it at LOW effort
and re-run only the failures one effort step up — before any other recovery.
Anthropic's own measurement (SWE-bench Pro): low-then-retry-at-default held
the pass rate of all-default at about half the cost. Two conditions: a real
failure signal (a checker that passes bad work forwards the failure instead
of catching it), and it never applies to the verify/judge stages of a
high-risk diff — those keep the strong floor (Keep a strong row strong). The
tier ladder (re-dispatch one TIER up on `BLOCKED`) is for capability gaps; this effort
ladder is for depth gaps — try the cheaper rung first.

**A command before a refuter.** Before spawning a per-finding verify agent, ask what a COMMAND can settle — a test, curl, a computed style, a grep — and run it in the same stage (or in the script itself: typed `schema` output plus a code check is the cheapest guardrail). Spend an LLM refuter only on the claims no command can check.

## Wide-effort profile

A wide-effort setting widens breadth inside the tier; it never adds a tier, a round or a strong slot.

- A wide-effort session runs no cross-family member (`cross-family` step 1).
- R1/R2 get at most one fleet: the one `convening-code-review` round for the tier, with a command or balanced refuter per MAJOR finding.

| Phase | Shape |
|---|---|
| Read-only research | a cheap fact pack → balanced readers, one facet each → verify only findings that change the answer → ONE strong critic on a digest |
| Define (R3+) | cheap scouts map code and past decisions; an open approach adds 2-3 balanced lens drafts + ONE strong judge |
| Plan | one author |
| Build | one role per disjoint slice, on main |
| Debug | the first repro does not point at the cause → 2-3 read-only balanced hypothesis testers, then ONE role fixer |
| Review | the tier's review set in one round + a command or balanced refuter per MAJOR finding |

Never fan out: user dialogue, plan authoring (one plan; several asked at once → `write-plan` step 8), the strong slot, writers on shared files, the fix for one failure, a review round 2, commit.

Critic and judge take a digest of verified findings, never the raw journal.

## Lead-tier fit — once per session

Classify your own model into a class (cannot tell → skip); tier classes only, never a model name.
- Strong-class Lead + three consecutive R1/R2 routes → note once that a balanced Lead plus rolepod's escalation valves (cross-model consults, strong reviewers, BLOCKED redispatch) covers routine sessions.
- Balanced-class Lead + an R4 or architecture route → note once that strong consults and reviewers are pulled in automatically; a strong Lead pays off only when that is the day's main work.
