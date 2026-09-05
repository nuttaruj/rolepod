# Hooks reference

Rolepod ships a family of **core bash hook scripts** in `hooks/`. Each CLI adapter declares the applicable ones in a plugin/extension `hooks/hooks.json` — Claude, Codex, Gemini, and Cursor all use the same `hooks/hooks.json` form (Cursor uses camelCase event names; the others use PascalCase). All hooks are **self-guarded** — silent no-op when a dependency is missing.

Lead does not invoke these manually. They fire automatically.

## Hook categories — All core (no add-on hooks)

| Category | Hooks | Purpose |
|---|---|---|
| **Always-on** | `always-on-loader` | Inject the rolepod always-on judgment core as SessionStart context |
| **Enforcement** | `block-subagent-commit`, `cohesion-contract-check`, `gate-reminder`, `precommit-gate` | Hard / soft blocks on discipline violations (high-risk path, parallel-without-contract, sub-agent commit, schema-bound new file) |
| **Context** | `project-context-loader` | Inject git state at SessionStart |
| **Session safety** | `session-lifecycle`, `worktree-guard` | `session-lifecycle`: SessionStart lock + Stop unlock. `worktree-guard`: hard-blocks an edit only when a live sibling owns that exact file — disjoint/solo edits flow free |
| **Answer-path** | `claim-verify-nudge` | Soft read-first nudge when a prompt asks for an analysis / diagnosis / "how does X work" / status — covers the claim/answer path that tool + lifecycle hooks miss. Since v2.49.0 also the **context-bloat check**: reads the last turn's context size from the transcript and, past 200k tokens, adds one note per 200k bucket per session — `additionalContext` for the Lead only (delegate reads to a scout; mention /compact or a fresh session to the user once, at a natural pause — the user-facing `systemMessage` was removed in v2.49.1 as friction). Measured need: a 12-day session ran every turn at 350-900k tokens; each turn re-reads all of it — one grep sweep = 31 turns × 558k ≈ $9. Claude/Codex `UserPromptSubmit`, Gemini `BeforeAgent`; soft, never blocks |

All core hooks register on every Claude install. rolepod-brain and GitNexus integrate via their own plugins/CLI, not rolepod hooks.

PR 6 dropped `verify-reminder.sh` (PostToolUse Edit/Write per-edit nag). The same discipline lives in:
- skill `check-work` — Iron Rule + evidence-required output contract
- `precommit-gate.sh` — hard-blocks commit on high-risk + zero tests
- skill `using-rolepod` — Verify phase exit gate

A per-edit reminder hook duplicated all three without enforcement teeth — so it was removed instead of replicated.

## Event coverage

| Event | Matcher | Hooks |
|---|---|---|
| `SessionStart` | `startup\|resume` | `always-on-loader.sh`, `project-context-loader.sh`, `session-lifecycle.sh --lock` |
| `UserPromptSubmit` | (no matcher) | `claim-verify-nudge.sh` |
| `PreToolUse` | `Edit\|Write\|MultiEdit` | `worktree-guard.sh`, `gate-reminder.sh` |
| `PreToolUse` | `Bash` | `precommit-gate.sh`, `block-subagent-commit.sh` |
| `PreToolUse` | `Agent` | `cohesion-contract-check.sh` |
| `PreToolUse` | `Workflow\|Agent` | `workflow-tier-nudge.sh` |
| `PostToolUse` | `Workflow\|Agent` | `dispatch-auto-log.sh` |
| `Stop` | (no matcher) | `session-lifecycle.sh --unlock` |

## Per-hook reference

### `claim-verify-nudge.sh` — UserPromptSubmit (core)

Two soft checks at the one moment before the Lead starts a turn; no new registration for the second.

- **Claim-check**: prompt looks like an analysis / diagnosis / status question → `additionalContext`: read the primary source and cite file:line before claiming.
- **Context-bloat check (v2.49.0)**: `session_state.py context-tokens` (input + cache_read + cache_creation of the last assistant turn) ≥ 200k → once per 200k bucket per session (state in `~/.rolepod/ctx-nudge/<session_id>`): `additionalContext` telling the Lead every turn re-reads all of it — dispatch `rolepod:scout` for sweeps, and mention `/compact` / a fresh session to the user ONCE when the task is done (Lead-facing only since v2.49.1: the user-facing `systemMessage` nag was removed on request; the Lead raises it in its own words at a natural pause). Why here and not a hook of its own: the cost driver measured on a real project was the Lead's own re-reads (~90 % of spend), and no existing hook looked at `usage`.
- **Self-guards**: no transcript / no usage → context branch silent; empty prompt with a bloated context still emits the context note.
- **Bypass**: `ROLEPOD_NUDGE_OFF=1` (both checks).

### `always-on-loader.sh` — SessionStart (core)

Deliver the rolepod always-on judgment core to a Claude session. A Claude
Code plugin has no always-on instruction surface — a plugin-root file is not
loaded — so this hook is that surface. It is why the pure-plugin install
writes nothing into `~/.claude/CLAUDE.md`.

- **Effect**: reads the judgment core shipped beside the script
  (`hooks/always-on-core.md`, ~4KB — identity, precedence, verify-first,
  simplest-viable, code search, communication, risky actions, hard stops;
  authored as `always-on-core.md.tmpl` + `core/fragments/`, resolved at
  render) and emits it as SessionStart `additionalContext`.
- **Self-guards**: core file missing → silent exit; non-JSON failure → emits
  `{}` rather than crashing the session.
- **Claude-only**: Codex loads its always-on core natively from
  `~/.codex/AGENTS.md`; Gemini from its extension `GEMINI.md`. Neither
  registers this hook.

### `project-context-loader.sh` — SessionStart (core)

Inject git context at session start.

- **Effect**: `additionalContext` with repo name, branch, dirty count, recent commits (last 5), hot files (last 7 days).
- **Self-guards**: not in a git repo → silent; non-JSON failure → emits `{}`.
- **Concurrent-session soft-warn (Codex / Gemini / Cursor)**: on the CLIs that have no `session-lifecycle` hook, this loader also registers a lock in the neutral `~/.rolepod/session-locks/<sha256(worktree)>/` dir and appends a soft warning when a live sibling (any CLI, <30 min) is present. On Claude it skips this (detected via `CLAUDE_PROJECT_DIR`) because `session-lifecycle` already owns the warning — no double-fire. This is the soft-warn-everywhere floor; the hard `worktree-guard` gate remains Claude-only.
- **What this hook does not do**: no add-on detection, no vendor-tool recovery, no first-session nag, no external-reviewer banner. Add-on availability is documented in README + skills, never nagged per SessionStart.

### `session-lifecycle.sh --lock` — SessionStart (core)

Detect sibling Claude session(s) in the same worktree to prevent concurrent-edit stomp.

- **Effect**: write own lock to `~/.rolepod/session-locks/<sha256(worktree)>/<session_id>.lock`. If sibling locks (<30 min old) detected → warn + suggest `git worktree add` path. Auto-prune stale locks (>30 min) and their `.files` registry. The lock dir is CLI-neutral so Codex/Gemini/Cursor sessions (which warn via their SessionStart context-loader) are detected too.
- **Self-guards**: not in a git repo → silent; no sibling → silent.
- **Bypass**: `ROLEPOD_ALLOW_SHARED_WORKTREE=1` (for intentional read-only review sessions).
- **Pair**: same script `--unlock` on Stop; `worktree-guard.sh` enforces per-file at edit time (this hook only warns once at start).

### `gate-reminder.sh` — PreToolUse Edit/Write/MultiEdit (core)

Schema-bound + high-risk edit guard. Silent on normal code edits (PR 5 slim — the generic Q1-Q4 reminder lives in the always-on core / AGENTS.md / the using-rolepod skill, read once per session, not per edit).

Fires output ONLY when:
1. **Schema-bound NEW file** (plugin.json, marketplace.json, hooks.json, extension manifests) → soft warn: WebFetch spec FIRST.
2. **High-risk path** (auth / authentication / authorization / billing / migration / secret / crypto / token / oauth / jwt / sso / saml / webhook / stripe / paypal / charge / invoice — illustrative; canonical regex in the script, parity-pinned by lean-surface) → soft warn + auto-Careful banner with reviewer list (qa-tester + Codex/Gemini when binaries present).
3. **High-risk path + evidence gap** → the banner is prefixed with what the commit gate WILL require (`⛔ COMMIT WILL BLOCK — …`): 0 test edits since the last commit → write the failing test first; high-risk edits with 0 strong reviewers since the last commit → dispatch `rolepod:universal-reviewer` / `rolepod:security-engineer` before committing. **Warn-only, never a deny (v2.47.0)** — edit-time HARD blocks were the measured reason a user set `ROLEPOD_GATES_SOFT` for good (CourtBook: 33 high-risk edits in one day → 116 unreasoned bypasses), which then silenced the commit gate too. One hard checkpoint, at commit; this hook informs. Evidence window = since the last commit, Lead + subagent transcripts (same reader as the commit gate).

- **Self-guards**: docs / lockfiles / non-high-risk code → silent.
- **Bypass**: `ROLEPOD_GATES_SOFT=1` silences the would-block wording (banner stays).

### `worktree-guard.sh` — PreToolUse Edit/Write/MultiEdit/NotebookEdit (core)

Enforcement layer for the concurrent-edit problem `session-lifecycle` only *warns* about. The SessionStart warning is advisory and scrolls out of context in a long session; this hook acts at the moment of risk — the edit — but **only on a real file collision**, so it never punishes solo or disjoint parallel work.

- **Mechanism**: a per-session touched-files registry (`<session_id>.files`) alongside the `session-lifecycle` locks, keyed by `sha256(worktree)`. On each edit it (1) scans live siblings' `.files` for the resolved target path, (2) refreshes its own `.lock` so an actively-editing session never goes stale, (3) records the target into its own `.files` **only on the pass path** (a blocked attempt must not claim ownership — that would deadlock the rightful owner).
- **Tiers**:
  - no live sibling → silent (record + pass)
  - live sibling, target file **not** shared → silent (record + pass) — disjoint work flows free
  - live sibling owns this **exact** file → `permissionDecision: deny` (real stomp) — points at `EnterWorktree` (native) then `git worktree add` fallback
- **Self-guards**: not in a git repo → silent; not an edit tool → silent; no file path → silent.
- **Bypass**: `ROLEPOD_ALLOW_SHARED_WORKTREE=1` (intentional shared session — read-only review, or coordinated file ownership).
- **Pair**: `session-lifecycle.sh --unlock` releases this session's `.files` at Stop so a sibling can pick them up.
- **Scope**: the per-file guard is Claude-only, but the underlying lock dir (`~/.rolepod/session-locks/`) is shared — `session-lifecycle.sh` now runs on Codex too, and the opencode plugin reads the same dir, so cross-CLI sibling *detection* (a Claude and a Codex session on the same checkout) is live; only the per-file deny remains Claude-only.

### `precommit-gate.sh` — PreToolUse Bash (core)

Escalates to HARD block at `git commit` time when the session touched high-risk code but never produced a test edit.

- **Effect** (evidence split by risk since v2.46.0): HIGH-RISK diff (path regex OR money-movement terms in staged added lines) → auto-pass ONLY on ≥1 strong-class adversarial reviewer dispatch (security-engineer / universal-reviewer, and NOT explicitly dispatched at a cheap/balanced model — `inherit` counts because `workflow-tier-nudge.sh` lifts it on a low Lead); other HARD blocks → ≥1 test edit or ≥1 reviewer dispatch. Every auto-pass logs to `~/.rolepod/gate-bypass.log` (read by `make stats`) + additionalContext note; insufficient evidence → `permissionDecision: deny`.
- **Evidence window (v2.47.0)**: counted **since the last commit** (`git log -1 --format=%ct` — git's clock, unaffected by denied attempts, hook-less commits, or a 12-day session; no commit yet → whole session) across the Lead transcript **plus the session's subagent transcripts** (`<session>/subagents/**/agent-*.jsonl` — Agent tool and Workflow fleets, mtime inside the window, 60 newest). Measured need: a CourtBook session where session-cumulative evidence from day 1 (`tests=303 strong=2`) would have cleared every commit on day 12, while the tests the Workflow agents actually wrote (79–566 edits/day) were invisible to the Lead-only reader.
- **Self-guards**: non-commit Bash → silent; non-high-risk session → silent.
- **Bypass**: not needed — evidence auto-passes. `ROLEPOD_GATES_PASSED=1` / `[gates: pass]` are legacy markers (same evidence check; never honored without it). The env-prefix form is deliberately not prescribed anywhere: permission layers read `ENV=1 git commit` as gate circumvention and block it before the hook runs.

### `block-subagent-commit.sh` — PreToolUse Bash (core)

Sub-agents cannot run `git commit` / `git push` / `gh pr merge` / `gh pr create` / `git reset --hard` / `git push --force`. Lead owns version-control state after qa-tester + universal-reviewer pass.

- **Trigger**: `agent_id` field populated (sub-agent call).
- **Effect**: `permissionDecision: deny` with agent_type in reason.
- **Self-guards**: Lead Bash (no `agent_id`) → silent.
- **Bypass**: none — hard rule. Real-world failure (backend-developer committed bypassing qa-tester floor) motivated this.

### `cohesion-contract-check.sh` — PreToolUse Agent (core)

When Lead is about to spawn the 2nd+ engineering agent within 10 events, requires a contract file (`contract.md` / `SPEC.md` / `cohesion.md` / `specs/*.md`) to exist in the session.

- **Effect**: `permissionDecision: deny` if 2+ agents spawned without contract.
- **Self-guards**: 1st agent → silent; contract present → silent.
- **Bypass**: `ROLEPOD_NO_CONTRACT=1` (single-domain Agent spawn legit).
- **Pair**: skill `write-plan` (cohesion-contract step).

### `workflow-tier-nudge.sh` — PreToolUse Workflow|Agent (core)

Re-injects the tier-per-stage rule at the one moment it is needed — when a Workflow script or Agent call is about to dispatch. The rule lives in the `using-rolepod` router, which is not loaded while authoring a fleet; without this nudge an entire fan-out silently inherits the Lead's model.

- **Fleet-tier gate (v2.48.0, widened v2.50.0 — the deny branch)**: under a **strong-class** Lead (or a non-empty unknown family — assumed strong for cost) and no `// tier-reason: <why>` (legacy `fleet-inherit:`) comment in the script, a Workflow with `agent()` fan-out is denied when (1) it has zero `model:` / `agentType:` overrides (whole fleet at the Lead's price), (2) it names ≥2 stages (`phase()` calls / `meta.phases` titles / `label:` prefixes) but pins the ONE balanced tier on all of them — measured escape hatch: after v2.48.0 every fleet passed by pasting `sonnet` on every stage — or (3) on a **high-risk-shaped fleet** (the script names money / auth / security / migration surfaces) a judgment-shaped stage (verify / judge / review / refute / rank / score / adversarial / critic / synthesis) has no strong, role-pinned, or variable tier anywhere — a strong Lead running its R4 judge below itself — and, since v2.72.0, under a **balanced or cheap** Lead too: inherit or a balanced pin on that judge stage is the inverse trap, denied the same way (the tier follows the work, not the Lead). Routine fleets (i18n, UI copy, docs) judge at balanced by policy (R2) — v2.51.1 narrowed the rule after it pushed opus critics onto routine work. The deny names the stages and the per-stage fix (sweep → haiku, build/verify → sonnet or `agentType:'rolepod:<role>'`, judge → opus or inherit) — re-submit the same script and it passes. Each deny logs `reason: no-tier | single-tier | all-strong | no-strong-judge | strong-spread` + `tiers` + `stages`. **v2.74.0 — one strong slot.** Observed (CourtBook `technician-payout-review`, sonnet Lead): `agentType:'rolepod:security-engineer'` on the Review stage plus 26 bare per-finding verify agents ran 30 × sonnet on a billing surface and the gate stayed silent — a role-pin counted as the strong stage, but strong roles render `inherit`, which under a low Lead IS the Lead. Now (a) a strong-role `agentType` counts as strong only under a strong Lead (no Workflow-path lift exists — reviewer opts usually come from a data array spread into `agent()`, so a text rewrite would not reach the call); (b) the low-Lead deny names the fix as ONE strong slot — `model:'opus'` on the single security-engineer / universal-reviewer call or on one final adjudicator that reads the verdicts, threaded (`model: r.model`) when the opts come from an array — never "opus on the judgment stage"; (c) the mirror trap is denied too (`strong-spread`): under a low Lead a strong literal on a fan-out call (interpolated `label`, or lexically inside `.map(` / `pipeline(` / `Array.from(` / a loop), on ≥2 stages, on a non-judgment stage, or on >2 calls. `strong-spread` never yields — dropping a pin is always possible, and a yielded paste is the very fleet the deny exists to stop. **Loop valve**: the same fleet name denied twice within 30 min → the third submission passes with a nudge (logged `action: yield`, surfaced by `make stats`) — a Lead that cannot satisfy the gate never spins; worst case is two extra turns (≈ $0.1-0.5 each) against the $100+ a strong-tier fleet leaks. Why a deny here and nowhere else in this hook: ultracode / workflow-heavy users run opus- or fable-class Leads and the platform default is inherit, so a model-less script bills the WHOLE fleet at the Lead's price — measured: 6 fleets in one day, 5,196 agent turns at opus/fable, ≈ $180 above the sonnet price for the opus share alone, with the soft nudge fired and ignored every time. Under a low-class Lead the fleet is already cheap → nudge only. Any per-stage `model:`/`agentType:` → silent. Each deny is logged as `phase: "dispatch-gate"` in phase-log (a denied fleet never reaches PostToolUse) and counted by `make stats` per reason; `ROLEPOD_GATES_SOFT=1` degrades it to the nudge (logged to bypass.log). Under a low-class Lead none of this fires (the fleet is already cheap; the low-Lead nudge names the judge stage).
- **Effect**: Lead-aware since v2.47.0 — the hook reads the Lead's current model from `transcript_path` (last assistant turn) and classifies its FAMILY (haiku = cheap, sonnet = balanced, opus/fable/mythos = strong, else unknown). Workflow with `agent()` fan-out and zero `model:` overrides → fleet-inherit nudge whose wording depends on the Lead's class (strong Lead: "pin build stages to sonnet — the whole fleet runs at the Lead's cost"; low Lead: "fine for build; the strong pass comes from an Agent-tool reviewer dispatch before commit"). `effort:` alone is depth, not tier — still nudged (it used to silence the hook and log as "mixed"). Platform sweep Agent (`Explore` / `general-purpose`) with no `model` → cheap-class reminder (`rolepod:scout` is frontmatter-pinned cheap → silent); `system-architect` under a low Lead → "pass model:'opus'".
- **Strong-role floor (the rewrite branch)**: `security-engineer` / `universal-reviewer` / `system-architect` (architect since v2.73.0 — in teammate mode it writes the team's spec + cohesion contract) render `model: inherit` on Claude (a fixed pin would DOWNGRADE a fable-class Lead — see `build/merge-agent.py`). Dispatched with no `model` under a **known-low** Lead, the hook returns `permissionDecision: "allow"` + `updatedInput` with `model: "opus"` (the Agent tool asks no permission of its own, so nothing is bypassed; upstream docs now apply `updatedInput` regardless of the decision — the Workflow path still gets no rewrite, see the fleet-tier gate above) and a `systemMessage` naming the lift. Unknown Lead family → untouched (failure = no lift, never a downgrade of a stronger session). Explicit `model:` on the call is the Lead's stated choice → never rewritten; an explicit low model on a strong role is named as a downgrade the commit gate won't count. Measured need: 0 explicit strong overrides across a whole project while the Lead ran sonnet 66 % of its turns. **Live-verified 2026-08-17** (`claude -p --model claude-sonnet-5 --plugin-dir …`): the lifted `universal-reviewer` transcript shows `claude-opus-5`, and PostToolUse `tool_input` carries the lifted `model` (so `dispatch-auto-log.sh` records the outcome, `floor: applied|missed`, rather than inferring it). Known edge: the Lead's model is read from the LAST assistant turn, which is persisted after PreToolUse — so the very first assistant action of a fresh session (no prior turn) reads as unknown and is not lifted; it logs `floor: missed` and `make stats` surfaces it.
- **Coordinator-loop check (v2.51.0)**: on an Agent dispatch that would be the Lead's **3rd sequential round-trip in one turn** (`session_state.py dispatch-rounds` — assistant messages carrying an Agent/Task tool_use since the last user prompt; parallel dispatches inside one message count once) → `additionalContext`, once per turn: every dispatch → wait → dispatch re-reads the whole context (size quoted) at the Lead's price; dependent multi-step fan-out belongs in a Workflow script whose stages chain outside the Lead. Borrowed from CCW's "Beat Model" (coordinator wakes only on callbacks) — the same cost driver measured here (Lead re-reads ≈ 90 % of spend). Merges with a tier note when both apply.
- **Self-guards**: any per-stage `model:` / `agentType:` present → silent; specialist writer agents → silent; no JSON / no input / no `session_state.py` → silent; no transcript yet (fresh session's first action) → nudge, never deny.
- **Bypass**: `ROLEPOD_NUDGE_OFF=1` (shared with `claim-verify-nudge.sh`).
- **Pair**: skill `using-rolepod` (tier-per-stage paragraph).

### `dispatch-auto-log.sh` — PostToolUse Workflow|Agent (core)

Auto-appends the dispatch intent line to `<git-root>/.rolepod/evidence/phase-log.jsonl` — automation over doctrine, because the manual "log EVERY dispatch" rule was forgotten by the model that wrote it.

- **Effect**: one JSONL line per dispatch — `phase: "dispatch"`, `provenance: "hook-auto"`, tool (Agent/Workflow), `agent_type` or workflow `name`, `model` (explicit value or `inherit`), `override`, and since v2.47.0 `lead_model` + `lead_class` (family word only — rename-proof within a family, `unknown` otherwise), `model_overrides` / `effort_overrides` counted separately (a Workflow is `mixed` only on `model:`), the model literals + `agent_types` the script names and their `tier_mix` (v2.48.1 — so `make stats` can tell a real per-stage spread from one model pasted on every stage), and `floor: "applied"|"missed"` on a strong review role dispatched under a low-class Lead — read from the PostToolUse `tool_input` (which carries the tier-nudge lift), never inferred.
- **Self-guards**: not in a git repo → silent; no JSON / non-dispatch tool → silent.
- **Bypass**: none (append-only bookkeeping, fail-open).
- **Pair**: `scripts/stats.sh` (Dispatch intent — hook-auto section), the `dispatch-proof` layer.

### `fix-loop-breaker.sh` — PostToolUse Bash (core)

Mechanical counter for fix→fail loops — sha1-fingerprints the whitespace-normalized command, counts consecutive non-zero exits per session, resets on a passing run. At the 3rd consecutive failure of the same command it injects the debug-issue Iron Rule #5 STOP text (stop fixing, write the hypothesis ledger, get ONE cross-model advisor opinion or escalate) as `additionalContext`. Exists because prose stops require the model to count its own attempts — a sub-sonnet-class Lead cannot (real case 2026-08-21: a Codex terra Lead looped a failing fix for many rounds with every hook enabled while the prose stops sat in context). Advisory, never blocks.

- **Effect**: `additionalContext` STOP nudge on every consecutive failure ≥ 3 of the same normalized command; state per session in `$TMPDIR/rolepod-loopbreak-<session_id>.json`.
- **Self-guards**: no JSON / non-Bash tool / empty command / no `session_id` → silent; `interrupted` (user cancel) → not counted; no detectable exit code → treated as success (never counts what it cannot prove failed); command mutated between rounds → not counted (identical-command loops only, stated in the header).
- **Bypass**: none (advisory-only; a strong Lead that already obeys the prose rarely trips it).
- **Pair**: `debug-issue` Iron Rule #5 + the AGENTS.md / hard-stops "third failed attempt" line — this is their mechanical backstop for Leads below the prose floor.

### `session-lifecycle.sh --unlock` — Stop (core)

Removes own session lock so the next session in this worktree does not see a phantom sibling. Same script as the SessionStart `--lock` invocation, different mode flag.

- **Effect**: `rm -f $HOME/.rolepod/session-locks/<sha256(worktree)>/<session_id>.lock` and the matching `.files` registry (releases the files `worktree-guard` recorded for this session).
- **Self-guards**: not in a git repo → silent; no `session_id` → silent.
- **Bypass**: none (idempotent cleanup).

## Bypass envs — when to use

| Env | When |
|---|---|
| `ROLEPOD_GATES_SOFT=1` | Iterating on doctrine itself; want warnings instead of hard blocks for one session. Set **permanently** (e.g. in a project's `settings.local.json` `env`) it silences the commit gate and the fleet-tier gate — the only hard checkpoints left — for good; `make stats` shows every use |
| `ROLEPOD_GATES_PASSED=1` | Human-only, set at CLI launch. Legacy for commits: the precommit gate auto-passes on windowed evidence, and an env-prefixed `git commit` is never prescribed (permission layers read that shape as gate circumvention) |
| `ROLEPOD_NO_CONTRACT=1` | Single-domain Agent spawn that doesn't need cohesion contract (e.g. read-only research agent) |
| `ROLEPOD_ALLOW_SHARED_WORKTREE=1` | Intentional shared session (read-only review, paired exploration) |

Never set these globally — apply per-command only. Hard rules exist because real-world failures triggered them. **And they are the user's hand only:** a model that meets a gate conflicting with a standing instruction surfaces the conflict with options (e.g. Lead cold self-review recorded as a limitation) — it never sets a bypass env itself. Hook block messages, the always-on core, and review-code all state this; a self-set bypass in `bypass.log` is a finding, not a workaround.

**Bypass accountability.** Every used bypass is appended to `<git-root>/.rolepod/evidence/bypass.log` as one JSON line — `{"ts","hook","var","reason"}` — with the reason taken from `ROLEPOD_BYPASS_REASON` (defaults to `"unreasoned"`). Logging never blocks and fails open. A silent bypass normalizes itself; a recorded one stays visible in review.

### Cross-family pool — `.rolepod/cross-family` (v2.76.0)

Cross-family is **opt-in and off by default**. Which CLIs may serve as the
reviewer / advisor is the user's choice, not PATH's: `<git-root>/.rolepod/cross-family`
(project) overrides `~/.rolepod/cross-family` (machine); one CLI per line in
preference order, `#` comments; **no file = off, `none` = off**:

```
# this machine has four CLIs; use three, agy first
agy
codex
opencode
```

Names: `codex` `claude` `agy` `cursor` `opencode` (the standalone Gemini
CLI is retired — a `gemini` line is skipped with a note). **Ask once:** the
SessionStart loader (`project-context-loader.sh` on Claude + Codex, the
gemini/agy `session-start.sh`) sees no file, no `~/.rolepod/cross-family.asked`
marker and at least one other-family CLI installed → tells the Lead to ask
the user this session (candidates from `rolepod-cross-family --candidates`)
and record the answer — names, or `none` — then drops the marker so it never
nags. Rolepod never enables it unasked. The Lead's own model family is
always excluded (`agy`
= google; `cursor` / `opencode` = the family of their configured default
model, else `unknown` and flagged). Consumers: `scripts/cross-family.sh`
(the runner — installed as `rolepod-cross-family`, shipped in every plugin
tree), `precommit-gate.sh`, `gate-reminder.sh`, `make doctor`,
`rolepod-stats`.

**Satellite-first is enforced at commit (`precommit-gate.sh`).** On a
high-risk diff, an internal strong reviewer (security-engineer /
universal-reviewer) clears the gate only after the pool was tried: either
the runner's anchored pass (raw file ≥ 500 bytes under
`.rolepod/evidence/external/` + the `reviewer:external` review line) or an
`external-fail` line since the last commit (every usable member failed, or
the enabled pool is empty). Cross-family off (no file / `none`), or a Lead
the hook cannot identify, keeps the pre-v2.76 behaviour — nothing is forced
on a user who did not opt in. Measured before: 210 dispatches
across nine repos, zero cross-family passes — the internal reviewer was one
Agent call away and counted the same.

### Per-repo risk-path override — `.rolepod/risk-paths`

The high-risk path list (auth/billing/payments/…) is built-in but repo-tunable. Create `<git-root>/.rolepod/risk-paths` with one extended regex per line:

```
# add repo-specific high-risk paths
+(^|/)pii(/|\.|_|$)
(^|/)gdpr-export
# exclude a false positive (this repo's "token" is a lexer, not a credential)
-(^|/)compiler/token
```

Bare or `+`-prefixed lines ADD patterns; `-`-prefixed lines EXCLUDE paths the built-in list would match; `#` starts a comment. Read by `precommit-gate.sh`, `gate-reminder.sh`, and `session_state.py`; absent file = built-ins only; unreadable file fails open. The strongest seed: paths whose git history shows the highest bugfix-commit density — measure, don't guess.

### Test-tampering lint — `hooks/test-diff-lint.sh`

Warn-only helper invoked by `precommit-gate.sh` (not a registered event hook). It greps the staged diff for the machine-checkable half of qa-tester's REJECT list: focus/skip markers added on the way to green, deleted test cases, snapshot files refreshed with no test-logic change, DB mocks added under integration/e2e paths. Findings ride into the gate's warn/deny message; the lint itself never blocks — over-firing a hard block trains users to bypass gates. Every finding is accompanied by the HUMAN-ONLY caveat: whether expected values were derived from the spec or captured from current output is a judgment no grep can make, so a green lint must never be read as "tests are good".

### Self-test — `make doctor`

`scripts/doctor.sh` proves the enforcement layer mechanically: syntax-checks every hook, fires the SessionStart loader, and drives the three deny paths (subagent commit, high-risk commit without tests, cross-session same-file edit) with synthetic fixtures — plus verifies bypass logging and prints the installed version + enforcement tier per CLI. Run it after any CLI upgrade: a vendor hook API change that silently kills a deny path is exactly what this catches.

### Env namespace — `ROLEPOD_*` vs `CLAUDE_CODE_*`

Rolepod uses the `ROLEPOD_*` prefix exclusively for its bypass envs. Framework-scoped, separate from Anthropic's `CLAUDE_CODE_*` namespace (which controls Claude Code's own runtime behavior).

| Prefix | Owner | Scope |
|---|---|---|
| `CLAUDE_CODE_*` | Anthropic / Claude Code | Core CLI behavior |
| `ROLEPOD_*` | Rolepod framework | Hook bypass + framework-level toggles |

If rolepod ever needs to override a Claude Code core behavior, use the `CLAUDE_CODE_*` env directly per Anthropic docs — don't shadow it with a `ROLEPOD_*` wrapper.

## Why hooks, not just doctrine

Doctrine (CLAUDE.md text) tells the model what to do. Hooks **enforce** it. Models drift, especially under flow-state success cues — soft reminders get ignored. Hard blocks via `permissionDecision: deny` are the only mechanism that survives drift.

Three real failures motivated the hard hooks:
1. Sub-agent ran `git commit` after marking COMPLETED, bypassing qa-tester floor → `block-subagent-commit.sh`
2. Lead spawned 2+ parallel agents without writing a cohesion contract first; agents produced incompatible interfaces → `cohesion-contract-check.sh`
3. Concurrent Claude sessions on same worktree stomped each other's edits → `session-lifecycle.sh --lock`

## Why no "spec required" hook

Spec discipline is enforced via:
- `core/skills/write-spec/SKILL.md` — Iron Rule + approval gate + self-review
- `using-rolepod` router — Define phase exit evidence

Adding a `PreToolUse Bash` hook that checks for `docs/rolepod/specs/<feature>-YYYY-MM-DD.md` before Build-phase skills would duplicate `precommit-gate.sh`, block legitimate trivial builds, and force a layout schema on user repos. Decision: keep spec gating as doctrine.

## Root vs Codex adapter parity

Root `hooks/*.sh` is canonical. The Codex adapter mirrors the hooks whose events Codex supports (`SessionStart`, `UserPromptSubmit`, `PreToolUse apply_patch|Bash`, `PostToolUse Bash`, `Stop`, `SubagentStart`/`SubagentStop` — per the official hooks reference, verified 2026-08-05):

- **`scripts/cross-family.sh` (all CLIs, not a hook, v2.76.0)** — the cross-family runner the hooks and skills call; `render_evidence_scripts` copies it into every plugin tree's `scripts/` next to `stats.sh`, and the hooks resolve it as `../scripts/cross-family.sh` from their own directory (fallback `~/.rolepod/bin/`). One command = pool from config → first usable different-family CLI, read-only, its default model, clean room → raw output + phase-log line anchored. Behavioural test: `tests/integration/cases/cross-family-runner.sh` (stub CLIs, sandbox HOME).
- **8 shared scripts render-copied** from canonical `hooks/` into `plugins/rolepod-codex/hooks/` by `build/render.sh` (since v2.39.0 — the hand-maintained mirror tree is gone): `gate-reminder.sh`, `precommit-gate.sh`, `project-context-loader.sh`, `claim-verify-nudge.sh`, `block-subagent-commit.sh`, `session-lifecycle.sh`, `test-diff-lint.sh`, `fix-loop-breaker.sh`. Codex uses the same event names, stdin JSON, and `hookSpecificOutput`/`permissionDecision` protocol as Claude, so the scripts are shared verbatim (all smoke-tested against Codex-shaped payloads). Only `hooks.json`, `subagent-model-log.sh`, and `agent-sync.sh` live in the adapter dir.
- **`agent-sync.sh` (Codex-only, SessionStart, v2.75.0)** — the Codex plugin manifest has no `agents` component, so `codex plugin marketplace upgrade` alone never refreshed the 16 role agents or the `~/.codex/AGENTS.md` block. The plugin now bundles both (`plugins/rolepod-codex/agents/rolepod-*.toml` + `agents/AGENTS.rolepod.md`, rendered by `build/render.sh`); on session start the hook compares the plugin version with `~/.codex/agents/.rolepod-agents-version` and, when they differ, copies changed `rolepod-*.toml` files in, prunes retired ones (prefix-scoped — user agents are never touched), and replaces ONLY the `<!-- rolepod:start -->` … `<!-- rolepod:end -->` block of `~/.codex/AGENTS.md` (content outside the block is preserved byte-exact; no block → appended; file missing → created block-only). Fail-open and silent unless something changed (then one `additionalContext` line). `ROLEPOD_AGENT_SYNC_OFF=1` disables it; `install.sh` writes the same stamp so a fresh install is not re-synced on first launch; honors `CODEX_HOME`. Proven by `tests/integration/cases/codex-agent-sync.sh` against a sandboxed HOME. **Trust gate (Codex policy, verified 2026-09-03 against the official hooks reference):** Codex records hook trust against the hook definition's hash and *skips* new or changed plugin hooks until the user reviews them with `/hooks` — so the first session after this hook lands (or after its definition changes) needs that one-time trust; `codex exec` has `--dangerously-bypass-hook-trust` for vetted automation only.

`always-on-loader`, `cohesion-contract-check`, `worktree-guard` stay Claude-only (`always-on-loader` is unnecessary on Codex/Gemini/Cursor — they load their always-on core natively from `AGENTS.md` / `GEMINI.md` / `rules/*.mdc`; `cohesion-contract-check` needs the pre-spawn `Agent` TOOL event — Codex's `SubagentStart` fires post-spawn and cannot deny; `worktree-guard` extracts `file_path`, which `apply_patch` input does not carry).

Drift is structurally impossible: the shared scripts have exactly one source (`hooks/`), `make test-render-clean` git-diffs the committed render output, and `tests/static/lean-surface.sh` pins the adapter dir to its two Codex-specific files.

## Cursor adapter mapping

The Cursor adapter ships **3 core hooks** in `adapters/cursor/scripts/`, parallel to Codex but with Cursor's I/O contract (stdin JSON / stdout JSON / exit-code 2 to deny):

| Claude hook | Cursor mapping |
|---|---|
| `always-on-loader.sh` (SessionStart) | replaced by `rules/always-on-core.mdc` with `alwaysApply: true` — Cursor's native always-on mechanism |
| `project-context-loader.sh` (SessionStart) | `scripts/project-context-loader.sh` on `sessionStart` — emits `{"additional_context": "..."}` |
| `gate-reminder.sh` (PreToolUse:Edit\|Write\|MultiEdit) | `scripts/gate-reminder.sh` on `preToolUse` with matcher `Write\|Edit\|MultiEdit` — emits `{"permission": "allow", "agent_message": "..."}` for soft warns and `{"permission": "deny", ...}` + exit 2 for hard blocks |
| `precommit-gate.sh` (PreToolUse:Bash) | `scripts/precommit-gate.sh` on `beforeShellExecution` with matcher `git[[:space:]]+commit` — same tiering (silent / soft / hard), same `ROLEPOD_GATES_HARD` / `ROLEPOD_GATES_SOFT`; **no evidence auto-pass** (Cursor exposes no session transcript), so `[gates: pass]` in the commit message body stays the release valve there |
| `session-lifecycle.sh` (SessionStart/Stop lock) | not ported — Cursor's session model differs from Claude's; sibling-session lock has no clear Cursor equivalent yet |
| `block-subagent-commit.sh` (PreToolUse:Bash) | not ported — Cursor's subagent identity differs; deferred until `subagentStart` payload is exercised |
| `cohesion-contract-check.sh` (PreToolUse:Agent) | not ported — same reason |
| `claim-verify-nudge.sh` (UserPromptSubmit) | not ported — Cursor's `beforeSubmitPrompt` is block-only (`{continue, user_message}`) and cannot inject pre-answer context; deferred until Cursor adds `additional_context` to that event ([feature request](https://forum.cursor.com/t/add-additional-context-to-beforesubmitprompt-hook-output/157231)) |

Cursor uses camelCase event names (`sessionStart`, `preToolUse`, `beforeShellExecution`) vs Claude's PascalCase. The `matcher` field accepts regex patterns matched against tool name (`preToolUse`) or full shell command (`beforeShellExecution`).

## Installation

Hooks are shipped in the rolepod plugin tree (`~/.claude/plugins/rolepod/hooks/`) and declared in the plugin's `hooks/hooks.json` (the canonical plugin-root form). Re-running install is idempotent. Migration steps (pre-2.0 installs) strip any legacy hook entries from `~/.claude/settings.json`.

To verify installation:
```bash
claude plugin list
# Should show "rolepod" as enabled

claude plugin details rolepod@rolepod
# Component inventory should list a Hooks line covering UserPromptSubmit, SessionStart, PreToolUse, Stop
```

Expected: 12 core hook scripts / 13 registrations (UserPromptSubmit × 1, SessionStart × 3, PreToolUse × 6, PostToolUse × 2, Stop × 1 — `session-lifecycle.sh` registers twice, `--lock`/`--unlock`).
