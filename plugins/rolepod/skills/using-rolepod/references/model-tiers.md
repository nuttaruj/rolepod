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
- strong — high-risk review (`security-engineer`, and the `universal-reviewer` `mode: adversarial` pass), architecture, `review-code`, `finish-work` when `review-code` fires, `deepen-codebase` (its explorer inherits a strong Lead, else takes a one-call strong override).

The Lead picks the class at dispatch; escalate only on a BLOCKED redispatch or a user ask.

## Keep a strong row strong

- A strong row dispatches with a strong pin; rolepod role files carry it.
- A spawn with no pin inherits the Lead. Under a balanced or cheap Lead that is a silent downgrade, so pass an explicit strong-class override on that ONE call, never on a fan-out.
- A downgraded strong role is not the strong slot. `universal-reviewer` runs balanced on every CLI; only its `mode: adversarial` pass takes a strong-class model, so pass the explicit strong-class override on that ONE dispatch. The commit gate checks a `security-engineer` dispatch, any model, not the tier.

## Fleets

- One strong slot per fleet: sweep = cheap · build = balanced · per-item verify = balanced at high effort · the ONE judge or security reviewer = strong.
- Never inherit the Lead's model across a fleet; never pin strong on a fan-out (price × N).
- A stage that writes runs a rolepod role, never a generic agent; a fan-out stage runs a role first (it pins the tier), a bare model class only when no role fits.
- Mechanics live in your CLI's `references/fanout-<cli>.md` (Claude: `fanout-claude.md`, Codex: `fanout-codex.md`); no file for your CLI → dispatch roles one at a time.

## Wide-effort profile

A wide-effort setting widens breadth inside the tier; it never adds a tier, a round or a strong slot.

- A wide-effort session runs no external member (cross-family): each kind takes its pool-off path; an explicit user ask still runs.
- R1/R2 get at most one fleet: the one review round `review-code` names for the tier, with a command or balanced refuter per MAJOR finding.
- R2 verify stays the checklist command (+ a browser observation for UI), never the full suite.

| Phase | Shape |
|---|---|
| R0 research | a cheap fact pack → balanced readers, one facet each → verify only findings that change the answer → ONE strong critic on a digest |
| Define (R3+) | cheap scouts map code and past decisions; an open approach adds 2-3 balanced lens drafts + ONE strong judge |
| Plan | one author |
| Build | one role per disjoint slice, on main |
| Debug | the first repro does not point at the cause → 2-3 read-only balanced hypothesis testers, then ONE role fixer |
| Verify | the checklist + the suite as one stage |
| Review | the tier's review set in one round + a command or balanced refuter per MAJOR finding |

Never fan out: user dialogue, plan authoring (one plan; several asked at once → `write-plan` step 8), the strong slot, writers on shared files, the fix for one failure, a review round 2, commit.

Critic and judge take a digest of verified findings, never the raw journal.

## Lead-tier fit — once per session

Classify your own model into a class (cannot tell → skip); tier classes only, never a model name.
- Strong-class Lead + three consecutive R1/R2 routes → note once that a balanced Lead plus rolepod's escalation valves (cross-model consults, strong reviewers, BLOCKED redispatch) covers routine sessions.
- Balanced-class Lead + an R4 or architecture route → note once that strong consults and reviewers are pulled in automatically; a strong Lead pays off only when that is the day's main work.
