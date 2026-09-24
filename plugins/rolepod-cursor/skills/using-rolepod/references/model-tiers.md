<!-- Load when delegating work, picking a model class, or running a fleet. -->

# Model tiers and fleets

Tiers are classes, never model names. Map them once onto the models the user has opted into (this CLI's always-on names them; never a full aggregator catalog). A model you cannot classify → balanced, and say so.

| Class | The set's… | Work |
|---|---|---|
| **cheap** | small / fast model | docs, PM, copy, read-only sweeps |
| **balanced** | mid flagship | ALL implementation, high-risk paths included — the net is the strong review floor, never the writer's tier |
| **strong** | top reasoning model | architecture, final-pass and adversarial review. A set whose top sits below frontier-class still gets the full review; the depth cap is a recorded LIMITATION |
| **apex** | strongest tier the CLI exposes | only on `review-code`'s apex triggers |

Route rows by class:
- cheap — vague build / doc / UI asks and repeat or legacy features (`write-spec`), prototypes, clear doc edits, `manage-context`, explain-only answers.
- cheap to balanced — `write-plan` against an existing spec, `qa-tester` hand-offs.
- balanced — executing a plan, multi-agent planning, `debug-issue`, `simplify-code`, perf, UI and infra builds, `check-work`, repo-wide sweeps, high-risk builds.
- strong — high-risk review, architecture, `review-code`, `finish-work` when `review-code` fires, `deepen-codebase` (its explorer inherits the Lead).

The Lead picks the class at dispatch; escalate only on a BLOCKED redispatch or a user ask.

## Keep a strong row strong

- A strong row dispatches with a strong pin; rolepod role files carry it.
- A spawn with no pin (a plain-prompt subagent, a bare Workflow `agent()`) inherits the Lead. Under a balanced or cheap Lead that is a silent downgrade, so pass an explicit strong-class override on that ONE call, never on a fan-out.
- A downgraded strong role is not the strong slot.

## Fleets — Workflow, ultracode, native fan-out

- One strong slot per fleet: sweep = cheap · build = balanced · per-item verify = balanced at high effort · the ONE judge or security reviewer = strong.
- Never inherit the Lead's model across a fleet; never pin strong on a fan-out (price × N).
- A stage that writes carries `agentType: 'rolepod:<role>'`; a bare `agent()` never edits product files.
- ≥3 dependent dispatches → a Workflow pipeline, not a Lead loop of dispatch → wait → dispatch: every Lead round-trip re-reads the whole context at the Lead's price.
- A strong call that must stay strong inside a fleet script carries the comment `// tier-reason: <why>`; it covers ONE call, never a fan-out.

## Effort never lifts the tier

`/effort`, ultracode and xhigh raise reasoning, not ceremony.
- R1/R2 get at most ONE Workflow, and it is the review: one read-only `universal-reviewer` pass.
- Design or judge panels and adversarial fan-out are R3+ work.
- R2 verify stays the checklist command (+ a browser observation for UI), never the full suite.

## Lead-tier fit — once per session

Classify your own model into a class (cannot tell → skip); tier classes only, never a model name.
- Strong-class Lead + three consecutive R1/R2 routes → note once that a balanced Lead plus rolepod's escalation valves (cross-model consults, strong reviewers, BLOCKED redispatch) covers routine sessions.
- Balanced-class Lead + an R4 or architecture route → note once that strong consults and reviewers are pulled in automatically; a strong Lead pays off only when that is the day's main work.
