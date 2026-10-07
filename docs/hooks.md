# Hooks reference

Rolepod's hooks are bash + python scripts in `hooks/` (canonical source). Each CLI adapter registers the ones its hook API can run. Every hook is self-guarded: a missing dependency, a non-git directory or bad stdin means a silent exit 0. The Lead never invokes them; they fire on their own.

**Design rule (v2.176.0).** A hook stays silent while the model follows the workflow. It speaks only on a real mistake. The evidence gate runs only on Claude, where its evidence is native (the transcripts). Deliberate evasion is out of scope by design: the hooks catch normal-flow mistakes, not a crafted bypass.

**Message shape (v2.92.0).** Every deny or nudge has three parts and nothing else:

1. **Fact** — what this call did, with its numbers (files, reviewers, stage names).
2. **Fix** — the exact change that makes the same call pass.
3. **Exception** — the escape hatch, always user-set or stated in the artifact.

The *why* — incidents, doctrine — lives in this file and in the hook's source comments, never in the message. No message literal is over 600 chars. A warning starts with `WARNING:` and never says `BLOCKED` or "retry"; a deny keeps `BLOCKED:`. No message names a key, path or env that switches a gate off.

## Gates by mode

The session captures `workflow.mode` (`lite` / `standard` / `full`) once at startup. One table in `hooks/lib/session-mode.sh` (`rolepod_gate_action <gate-id>` → `deny` / `warn` / `silent`) decides every gate below; the opencode plugin carries the same table as a JS `const`. No config key and no env changes a cell: the table is fixed per mode. No hook exits early in `lite` any more — the mode only changes what a gate does.

### Group A — gates that can block

| # | Gate | lite | standard | full |
|---|---|---|---|---|
| 1 | Commit stages a path under `docs/rolepod/` (unless `.rolepod/docs-tracked` exists) | deny | deny | deny |
| 2 | R4 (high-risk) commit with no `security-engineer` dispatch since the last commit (`lite`: fewer than two `universal-reviewer` lenses) | warn | deny | deny |
| 3 | Session edited a high-risk path and wrote no test | warn | warn | deny |
| 4 | Ordinary code commit with no test and no reviewer | silent | silent | deny |
| 5 | Sub-agent runs `git commit`, `git push` (incl. `--force`), `git reset --hard`, `gh pr create` or `gh pr merge` | deny | deny | deny |
| 6 | Sub-agent cannot-wait rules, all five shapes (listed under `block-subagent-commit.sh`) | deny | deny | deny |
| 7 | Generic agent writes outside `docs/rolepod/`, `.rolepod/` and scratch paths | warn | deny | deny |
| 8 | Role-less Workflow `agent()` writes a file | warn | deny | deny |
| 9 | `qa-tester` or `security-engineer` writes a file that is neither a test nor markdown | warn | deny | deny |
| 10 | `universal-reviewer`, `adversarial-reviewer` or `scout` writes a non-markdown file | warn | deny | deny |
| 11 | Edit of a file another live session in the same worktree already holds | deny | deny | deny |
| 12 | `bare-fanout` under a strong or unknown-class Lead | deny | deny | deny |
| 13 | `strong-fanout` | deny | deny | deny |
| 14 | `bare-writer` | deny | deny | deny |

A cell that is not listed as `deny` is a warning in that mode. A `silent` cell prints nothing.

**Plan-fleet exception (gates 12 and 14).** A fan-out passes when every `agent()` leaves `model` and `agentType` unset and every prompt names a result path under `docs/rolepod/plans/` — the plan fleet of `write-plan` step 8, which runs on the Lead's model. Any `model:` or `agentType:` on any call voids the exception. The check lives only in `workflow-tier-nudge.sh`.

**Per CLI.** Antigravity accepts deny responses only, so a `warn` cell is silent there (a platform limit, accepted). Cursor sends a warning as `agent_message`. opencode applies the same table in JS.

### Group B — warnings that never block

Every mode warns the way `standard` does; `lite` no longer skips them:

- tree-rewrite advisory while a detached cross-family review runs
- `test-diff-lint` findings L1 to L5
- `push-ref-check`
- `gate-reminder` (review in flight; "this R4 commit would block", once per path per session)
- loop breaker at the 2nd failure and from the 4th on
- route nudge, auto-resume note, context-check note
- self-do nudge
- another live session in the same checkout
- `subagent-core`
- `project-context-loader`

### Group C — silent records

On in every mode, because the gates above read them: session lock and edit registry (gate 11), dispatch log (evidence for gate 2), route record, the `phase: gate` row, the captured session profile and the config bootstrap. At session start, profile files older than 14 days are deleted.

## Event coverage (Claude)

| Event | Matcher | Hooks |
|---|---|---|
| `SessionStart` | `startup\|resume\|clear\|compact` | `session-start.sh` (captures the profile, then runs `always-on-loader.sh`, `project-context-loader.sh` and `session-lifecycle.sh --lock`; combined context is capped at 9,500 characters, core first) |
| `UserPromptSubmit` | — | `claim-verify-nudge.sh` |
| `PreToolUse` | `Edit\|Write\|MultiEdit` | `worktree-guard.sh`, `gate-reminder.sh`, `subagent-write-scope.sh` |
| `PreToolUse` | `NotebookEdit` | `subagent-write-scope.sh` |
| `PreToolUse` | `Bash` | `precommit-gate.sh`, `push-ref-check.sh`, `block-subagent-commit.sh` |
| `PreToolUse` | `Workflow` | `workflow-tier-nudge.sh` |
| `PreToolUse` | `Agent\|SendMessage` | `block-subagent-commit.sh` |
| `PostToolUse` | `Workflow\|Agent` | `dispatch-auto-log.sh` |
| `PostToolUse` | `Bash` | `fix-loop-breaker.sh` |
| `SubagentStart` | `^(workflow-subagent\|general-purpose)$` | `subagent-core.sh` |
| `Stop` | — | `session-lifecycle.sh --unlock` (+ route record) |

13 registered hook scripts, 15 registrations (`subagent-write-scope.sh` and `block-subagent-commit.sh` register twice). `always-on-loader.sh` and `project-context-loader.sh` run from `session-start.sh`, and `test-diff-lint.sh` runs from the commit gate; none of the three is registered itself. All hook Python runs `python3 -I`, so a stray `json.py` in the working directory cannot mute a hook.

**Cursor host guard (v2.130.1).** Cursor auto-imports Claude Code plugins and runs their `hooks/hooks.json`. Every Claude manifest command is therefore `[ -z "$CURSOR_PROJECT_DIR" ] && exec bash "${CLAUDE_PLUGIN_ROOT}/hooks/<x>.sh"; cat >/dev/null`: under Cursor the imported copy drains stdin and exits 0, and the Cursor-native plugin owns the host. Disable the imported copy on Cursor's Plugins page to stop its agents and skills loading twice.

## Per-hook reference

### `precommit-gate.sh` — PreToolUse `Bash`

The one hard checkpoint, at `git commit`.

- **Private docs (every CLI, every mode)** — a staged path under `docs/rolepod/` → deny. Details under Private working docs below.
- **High-risk diff (Claude only)** — a staged path matching the high-risk regex or `.rolepod/risk-paths` and no `security-engineer` dispatch FINISHED since the last commit → `lite` warns, `standard` and `full` deny. In `standard` and `full` a high-risk commit needs at least one `security-engineer` dispatch since the last commit, any model; an external pass never counts. Fix: dispatch `security-engineer`. In `lite` (which forbids that role) the evidence is the two `universal-reviewer` lenses (spec, standards) since the last commit: two or more pass silently, fewer warn naming the two lenses.
- **Session risk without a test (Claude only)** — the session edited high-risk code, wrote no test, and the staged diff is not high-risk → `full` denies until a failing test is written or a reviewer has run; `lite` and `standard` warn.
- **Ordinary code without a test or reviewer (Claude only)** — `full` denies; `lite` and `standard` stay silent.
- **Everything else** — silent. `test-diff-lint` findings, when present, print as one line in every mode. Each judged commit appends a `phase: gate` row that `scripts/ticket.sh log` in `implement-plan` copies into the plan.
- **What counts as high-risk** — the path regex (auth / billing / payment / migration / secret / crypto / token / oauth / webhook … — canonical list in the script, parity-pinned by lean-surface) plus `.rolepod/risk-paths`. Test-named files (`*.test.*`, `test_*.py`, `*_test.go` …) and prose files never count. A bare directory name (`tests/`, `spec/`) is not an exemption.
- **Evidence (Claude)** — counted since the last commit (a linked worktree follows its own HEAD reflog): the Lead transcript plus the session's sub-agent transcripts (60 newest), MAX with the phase-log `dispatch` rows of provenance `hook-auto`. A write-mode brief never counts as a review; `qa-tester` never counts toward the high-risk floor, and `universal-reviewer` counts only in `lite` (two dispatches); `security-engineer` counts at any model; an anchored external pass counts for nothing (the gate does not read the cross-family pool).
- **Which commit it judges** — `cd <dir> &&` and `git -C <dir>` move the diff directory; `bash -c`, `eval` and the common wrappers (`env`, `timeout`, `sudo` …) are unwrapped; `git add … && git commit` and `git commit -a` are judged on the working tree. Anything unresolvable falls back to the hook's cwd — never a new deny.
- **Review in flight** — a tree-rewriting git command (`stash`, `reset --hard`, `checkout`, `rebase`, `merge` …) while a detached cross-family job runs → one advisory line naming `--collect`.
- **Incidents** — a sub-agent-heavy day where high-risk commits cleared on stale day-1 evidence (window is now since the last commit); 672 green tests + an opus build still shipped 4 money bugs only the adversarial pass caught (high-risk needs a `security-engineer` review, not tests).
- **Bypass** — none: evidence auto-passes, and each gate's action is fixed per mode (see Gates by mode).

### `gate-reminder.sh` — PreToolUse `Edit|Write|MultiEdit` (Claude)

- **Effect** — on a high-risk path, ONE line when the R4 commit gate would act on it now: fact (a high-risk commit needs at least one `security-engineer` dispatch since the last commit, any model; an external pass never counts) → Fix (dispatch `security-engineer`, finished before commit) → Exception. In `standard` and `full` the line says the commit will block; in `lite` it is a `WARNING:` and asks for the two `universal-reviewer` lenses (spec, standards) instead of `security-engineer`, silent once two are finished. Every other edit → silent. A sub-agent edit (`agent_id` set) gets neither this line nor the evidence scan (the Lead dispatches), only the review-in-flight advisory.
- **In-flight lines** — a live detached cross-family review whose diff holds the edited file → `⏸ REVIEW IN FLIGHT` (the job reads the tree live; editing now makes its verdict an artifact).
- **Throttle** — the would-block line comes once per path per session (state: ~/.rolepod/gate-reminder/<session_id>, pruned after 14 days); a new path, a new session or a payload with no session id gets it again; the in-flight line repeats on every matching edit.
- **Incident** — edit-time hard blocks once pushed a user to switch the whole gate layer off for good (33 high-risk edits in a day, 116 unreasoned bypasses), which silenced the commit gate too; this hook only informs.
- **Bypass** — none (informational).

### `block-subagent-commit.sh` — PreToolUse `Bash` (Claude, Codex) · `Agent|SendMessage` (Claude)

- **Commit ban** — a sub-agent (`agent_id` set) running `git commit` / `git push` / `gh pr create` / `gh pr merge` / `git reset --hard` / `git push --force` → deny. The Lead owns version-control state. Wrapped forms (`timeout 300 git commit`, `xargs git commit`) are caught; a pure-output head (`echo`, `printf`) and a data heredoc are not.
- **Codex** — the commit ban runs there too: a sub-agent's `git commit` / `git push` is denied — a child's PreToolUse carries `agent_id` (live probe 2026-09-30, Codex 0.159). The cannot-wait rule below is Claude-only.
- **Cannot-wait rule (Claude)** — a sub-agent Bash call with `run_in_background: true`, or a cross-family gate (`--kind …` without `--detach`, or `--collect`) with no `timeout` → deny. A sub-agent `Agent` call with an explicit `run_in_background: true` → deny; an unset flag passes (live probe 2026-09-29, Claude Code 2.1.284: the Agent tool has no `run_in_background` parameter and a child's end wakes the sub-agent that ended its turn to wait for it — in the terminal CLI only; the desktop app sends it to the Lead, which relays it to the owner whose return ends `WAITING: <report paths>`, live probe 2026-09-29). A `name`, a `fork` or `isolation: remote` → deny — those always run as a background teammate whose report goes to the Lead (a named child with `run_in_background: false` still spawned as a mailbox teammate). A sub-agent `SendMessage` to a raw agent id (`a` + hex — how an owner addresses the unnamed reviewer it spawned) → deny: the message resumes that agent in the background; a named target (`main`, `team-lead`, another owner) passes. The deny's Fix: a round-2 re-check is a fresh `Agent` dispatch of a `universal-reviewer`, not the same role, with its report and the fix delta in the brief. A resumed or teammate child reports to the Lead, and nothing wakes the sub-agent. In-process teammates carry `agent_id` too (live probe, 2026-09-29).
- **Incidents** — a `backend-developer` committed past the QA floor after marking COMPLETED; a task owner idled its whole budget waiting on a backgrounded gate; an R4 task owner dispatched its four reviewers in the background, ended its turn "waiting for their notifications", and idled 6.6 h while the reports sat with the Lead (2026-09-28).
- **Bypass** — none.

### `subagent-write-scope.sh` — PreToolUse `Edit|Write|MultiEdit|NotebookEdit` (Claude)

A sub-agent writes only what its role owns.

| Class | `agent_type` (namespace stripped) | May write |
|---|---|---|
| generic | `general-purpose`, `default`, `claude`, `workflow-subagent` (a bare Workflow `agent()`) | nothing in the product tree |
| test-only | `qa-tester`, `security-engineer` | test paths (`tests/`, `__tests__/`, `fixtures/`, `e2e/`, RSpec `spec/`, `*.test.*`, `*.spec.*`, `test_*.py`, `conftest.py`, test-runner config …) + markdown |
| read-only | `universal-reviewer`, `adversarial-reviewer`, `scout` | markdown only |

- **Effect** — gates 7 to 10 of the mode table: `lite` warns (`WARNING:` + fact → Fix → Exception), `standard` and `full` deny; a denied sub-agent returns the finding and the Lead dispatches the owning role. A `phase: write-scope` row lands in the phase-log for each in-root deny. Owning roles, the Lead, an unknown `agent_type`, OS temp roots and scratch / evidence paths (`scratchpad/`, `.rolepod/`, `.claude/agent-memory/`, `docs/rolepod/`) pass. A path outside the git toplevel of the payload `cwd` passes too, usually a sub-agent's memory file under `~/.claude/projects/`; the main checkout of a linked worktree still counts as inside, and with no resolvable root nothing is skipped.
- **Doctrine pair** — the agent protocol says a nested dispatch goes only to the rolepod role the brief or the Writer loop names; this hook is the backstop when it does not.
- **Incident** — 16 of 31 `general-purpose` dispatches edited product code with no role doctrine; `qa-tester` wrote 99 non-test product files.
- **Not enforced** — an owning role drifting into another domain (the brief's Files allowed bounds it); a write through the shell (doctrine: edit tools only).
- **Bypass** — none documented; the action per class is fixed by mode.

### `worktree-guard.sh` — PreToolUse `Edit|Write|MultiEdit` (Claude)

- **Per-file deny** — a live sibling session in the same worktree already edited this exact file → deny, pointing at `EnterWorktree` then `git worktree add`. No sibling, or a different file → silent. A file is recorded as this session's only on the pass path, so a blocked attempt never claims it.
- **Self-do nudge (v2.116.0)** — the Lead (no `agent_id`) edits product code after its own routing line with no writer-role dispatch since: route R2 → at the first edit; route R3/R4 → at 6 edits. One line per route. R2: go to a task owner on main from the 3-5 line checklist. R3/R4: brief the Owner the map names; the Lead reads the decision brief and spot-checks one claim. Exception: the user said self-do, or the change is R1-sized. Warns in every mode.
- **Incident** — two Claude sessions on one worktree stomped each other's edits.
- **Bypass** — none documented; the deny is the same in every mode.

### `workflow-tier-nudge.sh` — PreToolUse `Workflow` (Claude)

A Workflow `agent()` call defaults to the Lead's model and no frontmatter can change that, so this hook reads the script before it runs. Three denies, in every mode and none yields, except the plan-fleet exception below (checked in this order: `bare-fanout`, `strong-fanout`, `bare-writer`; a script with both fan-out shapes gets ONE deny, verdict `bare-fanout+strong-fanout`, naming both stage lists):

- **`bare-fanout`** — under a strong-class or unknown Lead, a fan-out `agent()` call (interpolated label, or inside `.map(` / `pipeline(` / `Array.from(` / a loop) with no tier. A tier is a `model:` or an `agentType:` that pins one (a rolepod role; a variable counts); a platform `agentType:` such as `general-purpose` pins nothing. Fix: pin every fan-out (a writing stage → a non-strong rolepod role) — sweep → cheap or `rolepod:scout`, build and per-item verify → balanced, the ONE judge → strong.
- **`strong-fanout`** — under any Lead, a fan-out `agent()` call pinned strong (a strong `model:` or a strong-role `agentType:`). Fix: the fan-out runs a non-strong role or haiku / sonnet; keep ONE strong judge outside the fan-out.
- **`bare-writer`** — under any Lead, an `agent()` with no `agentType:` on a stage whose name says it writes (Implement / Build / Fix / Integrate / Migrate / Refactor / Patch / Scaffold / Write). Fix: `agentType: 'rolepod:<role>'`. Without it `subagent-write-scope` blocks the first write minutes into the run.
- **Plan fleet** — a fan-out whose every `agent()` sets no `model:` and no `agentType:` and whose prompts name a result path under `docs/rolepod/plans/` passes `bare-fanout` and `bare-writer` (it is the `write-plan` step 8 fleet on the Lead's model). One `model:` or `agentType:` anywhere voids it. `strong-fanout` has no exception.
- **Lead class** — the family word of the Lead's last transcript turn (haiku = cheap, sonnet = balanced, opus / fable / mythos = strong, else unknown).
- **Logging** — each deny appends a `phase: dispatch-gate` row (a denied fleet never reaches PostToolUse).
- **Incidents** — six fleets in one day ran at opus/fable with a nudge ignored; a role-less writing agent worked 96 turns before its first write was blocked.
- **Bypass** — none; the denies are the same in every mode.

### `subagent-core.sh` — SubagentStart `workflow-subagent|general-purpose` (Claude)

A bare Workflow `agent()` and a general-purpose Agent-tool sub-agent carry no role file, so they got none of the agent protocol. This hook adds the short core (one ~500-char `additionalContext`: output is data, verify at file:line, batched reads, command timeouts, Edit/Write only, no commit, answer through the schema). A `rolepod:<role>` agent is never matched (its definition already carries the protocol); the matcher is anchored because plugin agent types contain a colon, which puts the matcher on the regex path, and the hook re-checks `agent_type` itself.

- **Observational** — SubagentStart cannot block; the hook only adds context and prints `{}` for any other agent type.
- **Bypass** — none (observational, on in every mode).

### `dispatch-auto-log.sh` — PostToolUse `Workflow|Agent` (Claude)

- **Effect** — one `phase: dispatch`, `provenance: hook-auto` row per dispatch in `<git-root>/.rolepod/evidence/phase-log.jsonl`: tool, `agent_type` or workflow name, `model` (explicit value, `opus` for a model-less strong role, else `inherit`), `lead_model` / `lead_class`, model and effort overrides, `tier_mix` (only agentTypes that render a pin count as tiered). The commit gate reads these rows as its nested-reviewer backstop; `rolepod-stats` reads them for the dispatch and fleet-cost sections.
- **Incident** — the manual "log every dispatch" rule was never followed by the model that wrote it.
- **Bypass** — none (append-only, fail-open).

### `fix-loop-breaker.sh` — PostToolUse `Bash` (Claude, Codex, opencode)

- **Effect** — fingerprints the whitespace-normalized command and counts consecutive non-zero exits per session; a passing run resets it. At the 2nd consecutive failure of the same command → one note: consult once, via `debug-issue`'s Second opinion step (hypothesis ledger → second opinion → escalate), after two actual failed fixes. From the 4th failure → a stop note: if it is the fourth failed fix for the same repro or criterion, stop and ask the user with the attempt log. Command failures are only a proxy for failed fixes. Advisory in every mode, never blocks. A user cancel, an undetectable exit code or a changed command is not counted.
- **Incident** — a weaker Lead looped a failing fix for many rounds while the prose stop rule sat in context; counting its own attempts is what it could not do.
- **Bypass** — none (advisory).

### `push-ref-check.sh` — PreToolUse `Bash` (Claude)

- **Effect** — a real `git push` that would publish 2 or more commits (`@{push}..HEAD`, or the remote's default branch when there is no upstream) → names each commit and asks you to confirm each is yours or cleared by its author. One commit → silent. Never denies.
- **Incident** — in a shared worktree another session's local merge rode out on an unrelated push.
- **Bypass** — none (informational).

### `claim-verify-nudge.sh` — UserPromptSubmit (Claude, Codex)

- **Route nudge (v2.98.0)** — a commission-shaped prompt while the newest `phase: route` line predates the previous prompt → one `⟂ route:` line asking for the R0-R4 tier before the first edit (full text on the first nudge of a session, a one-line reminder after). A question-shaped prompt and a harness background-task notification (`<task-notification>`) are not commissions and never get it. Incident: 199 requests, 0 router invocations in one project.
- **Auto-resume (v2.100.0)** — the harness's "continue from where you left off" prompt is a resume, not a user decision: a turn that ended at a question is restated, never continued into new scope.
- **Context-bloat note** — the last turn's context crosses 400k tokens → one Lead-facing note (sweeps go to `rolepod:scout`; mention `/compact` or a fresh session to the user once); re-arms only after the context drops under the line. Incident: a 12-day session re-read 350-900k tokens every turn.
- **Bypass** — none (advisory, on in every mode).

### `session-lifecycle.sh` — SessionStart `--lock` / Stop `--unlock` (Claude, Codex)

- **`--lock [--cli <name>]`** — writes `~/.rolepod/session-locks/<sha256(worktree)>/<session_id>.lock` with the CLI name as its content (`--cli claude` / `--cli codex` from each hooks.json; the Cursor, Antigravity and opencode adapters write their own name); a live sibling lock (< 30 min) → one warning suggesting `git worktree add`, naming the CLIs behind the locks (`2 active: opencode ×2`; an empty or unreadable lock reads `unknown`). Stale locks (> 30 min) are swept in every worktree's lock dir. The lock dir is shared by every CLI, so a Claude and a Codex session on one checkout see each other.
- **`--unlock`** — removes this session's lock and its `.files` registry (releasing what `worktree-guard` recorded), then runs the route record. `.rolepod/parent-active` stays (v2.180.5): Stop fires at the end of every turn, so removing it there dropped child plugins to standalone mode from turn 2 on.
- **Per-turn lock (accepted gap)** — the lock lives from SessionStart to the turn's Stop. Claude re-touches it on each edit (`worktree-guard`), so an editing Claude session stays visible; Codex has no edit hook, so a Codex session is visible to siblings only until its first Stop. No workaround hook: a CLI without the event goes without.
- **Route record (v2.105.0)** — `lib/route_check.py --record` reads the finished turn's assistant text and, when it holds a routing line at line start (`Route: R2 …` / `Tier: R3 …` / the arrow form), appends one `phase: route` row. Fenced code, placeholders and ranges (`R0-R4`) are ignored. Every CLI records it from its own transcript (Cursor `stop-unlock.sh`, agy `stop-unlock.sh`, opencode from the plugin). Incident: the manual route append was written 0 times across every product repo.
- **Bypass** — none (the lock is a silent record in every mode).

### `project-context-loader.sh` — SessionStart (Claude, Codex, Cursor)

- **Effect** — repo name, branch, dirty count, the last 3 commits (each subject cut to one line), hot files (7 days; manifest churn such as `plugin.json` and lockfiles skipped), the last phase-log line, and an **Open plan** pointer: the newest plan, showing each task's status as 'Task N/M done · running: ... · next: ...' by task.
- **Context only** — the session lock, the sibling warning and `.rolepod/parent-active` belong to `session-lifecycle` on Claude and Codex (Codex launches SessionStart hooks concurrently, so a second lock writer here read as a phantom sibling and outlived Stop). Cursor ships its own loader, which keeps its `cursor-<conversation_id>` lock.
- **Cross-family** — no pool file and a second CLI installed → one context line pointing at the `cross-family` skill's setup steps, never a question.
- **Bypass** — none (context only).

### `always-on-loader.sh` — SessionStart (Claude)

Emits `hooks/always-on-core.md` (identity, precedence, verify-first, simplest-viable, code search, communication, risky actions, hard stops; rendered from `always-on-core.md.tmpl` + `core/fragments/`) as `additionalContext`. A Claude plugin has no other always-on surface, which is why the plugin install writes nothing into `~/.claude/CLAUDE.md`. Other CLIs load the same core natively (`AGENTS.md`, `rules/*.mdc`). Missing core file → silent.

### `test-diff-lint.sh` — helper (called by `precommit-gate.sh`)

Warn-only grep of the staged diff: focus / skip markers added, deleted test cases, snapshots refreshed with no test-logic change, DB mocks under integration / e2e paths, a literal calendar date under a test path. Findings print as one line at commit. Each finding states the fact and count, then Fix (the date finding adds an Exception); no trailing caveat.

## Removed in v2.176.0

| Removed | Reason |
|---|---|
| `AUTO-CAREFUL` banner on every high-risk edit | normal-flow noise — careful mode was removed in v2.171.0; the one would-block line replaces it |
| `T-gate violation`, the S/T/F list and "preferred" in the deny text | normal-flow noise — the deny now names only what clears it |
| Money-term content check (refund / payout / chargeback / settlement in added lines) | normal-flow noise — it flagged UI labels, i18n values and rendered prose (blocked this repo at v2.175.0) |
| Edit ledger: `hooks/edit-ledger.py`, `.rolepod/evidence/edits.jsonl`, every writer and reader | platform twin — the evidence is native only on Claude |
| `dispatch-proof` rows: Codex `subagent-model-log.sh`, Cursor `dispatch-log.sh`, agy `model-log.sh`, the opencode task hook, the cross-family runner | platform twin — `rolepod-stats` no longer reads them |
| The evidence gate on Codex, Cursor, Antigravity and opencode (the gate's lib-less branch included) | platform twin — parity is skills + workflow; those CLIs keep the private-docs deny |
| Cursor `gate-reminder.sh` (`preToolUse` and `postToolUse`); Codex `apply_patch` → `gate-reminder.sh` | platform twin |
| `block-subagent-commit.sh` shell-write rule (`bash_write_paths()`, its ledger rows, the synthesized write-scope check; the Codex copy of `subagent-write-scope.sh`) | dead path — it fed the removed ledger; "edit tools only" stays doctrine |
| Fleet gate `no-tier`, `single-tier`, `no-strong-judge`, `strong-spread`, `named-downgrade`, the loop valve, the low-Lead nudge, the `// tier-reason:` escape | normal-flow noise — three denies cover the measured cases |
| Fleet gate on `Agent`: the `updatedInput` → `opus` floor and the downgrade nudge | dead path — strong roles render `opus` in frontmatter since v2.104.0 |
| `dispatch-auto-log` `floor: applied` value | dead path — nothing lifts a model any more |

## Changing gate strictness

You change strictness with `workflow.mode` in `~/.rolepod/config.json` (a project's `.rolepod/config.json` overrides it); each mode's gate table is fixed (see Gates by mode). No config key and no env turns one gate off. A model that meets a gate that conflicts with an instruction surfaces the conflict with options; it never works around the gate itself. The cross-family pool is the `pool` object in the same file.

## Cross-family pool — `~/.rolepod/config.json` `pool` key

Opt-in and off by default. Machine-wide only; no project-level override. Set in `~/.rolepod/config.json` under the `pool` key: `pool.cross-family` ("on"|"off"), `pool.reviewer` (review/consult/critique). Use `cross-family.sh --setup` or hand-edit; `cross-family.sh --pool` shows the resolved pool.

- **Members** — space-separated: `codex`, `claude`, `agy`, `cursor`, `opencode`. List every CLI you use in the order you prefer for each kind. The Lead's own CLI is skipped at run time, so one file serves every Lead. The model family is recorded for information and never filters a member.
- **Time** — a member is killed when it goes SILENT for `stall` seconds (config `stall=` → 600), not when it is slow; the wall-clock cap is runaway insurance only (review 7200 s detached / 600 s foreground, consult 300, critique 600). `--detach` runs the chain as a job under `.rolepod/evidence/external/jobs/<id>/`; `--collect <id>` waits, `--jobs` lists.
- **Refusals** — a partial-slice diff (its files have edits it does not contain) → exit 7, attach `git diff HEAD` or commit first (`--partial-ok` only when the user asked for the staged part); a second live review job → exit 8 until `--collect` or `--kill`.
- **Rounds** — externals run in round 1 only: R3 / R4 diffs run the spec and standards lenses external, Full R4 adds external adversarial; round 2+ is internal: one fresh `universal-reviewer` re-checks the fix delta (H1→H2) of every BLOCKER / MAJOR finding in one pass, whichever reviewer or external raised it (`convening-code-review` Fix-verify; at most four rounds, round 1 included). A pre-existing issue on an untouched path is one note line and never drives the verdict.
- **At commit (Claude)** — an external pass is not read by the gate (C4, see `precommit-gate.sh`). A docs-only diff passes the gate at any size (docs are written, not reviewed — owner rule).

## Private working docs — `docs/rolepod/` never commits (v2.80.0)

Specs, plans, contracts and hand-off briefs under `docs/rolepod/` describe what you are building before it exists, so they are private by default. The skills add `docs/rolepod/` to `.gitignore` on the first save, and the commit gate on every CLI denies a commit that stages a path under it (the classic leak is `git add -A`). A repository that deliberately tracks them creates `<git-root>/.rolepod/docs-tracked` and the gate steps aside. ADRs under `docs/adr/` are unaffected.

## Per-repo risk-path override — `.rolepod/risk-paths`

```
# add repo-specific high-risk paths
+(^|/)pii(/|\.|_|$)
(^|/)gdpr-export
# exclude a false positive (this repo's "token" is a lexer, not a credential)
-(^|/)compiler/token
-(^|/)design-templates/invoice(/|$)
```

One extended regex per line: bare or `+` adds, `-` excludes a path the built-in list would match, `#` comments. Read by `precommit-gate.sh`, `gate-reminder.sh`, `session_state.py` and `plan-lint.sh --brief` (awk — keep patterns POSIX ERE, no `\b` / `\S`). Absent file = built-ins only; unreadable fails open. A prose file is never a risk path, even with a `+` line. Seed it from measurement: the paths with the highest bugfix-commit density.

## Ticket helper — `ticket.sh` (v2.155.0)

`scripts/ticket.sh` in the `implement-plan` skill turns a plan task's mechanics into two Lead calls:

- **`start <plan> <N> [--base <branch>]`** — runs `plan-lint`, writes the owner brief, creates the worktree + branch, prints the dispatch line and a `ship:` line with `<commit gate>` / `<subject>` / `<note>` to fill in. Idempotent.
- **The ship chain** — one Bash call after the owner returns; a red step stops it before the commit:
  1. `integrate <worktree> --brief <file> --gate '<cmd>'` — fast-forward to the base, stage everything except `docs/rolepod/`, run the brief's Proof, then the gate.
  2. `git -C <worktree> commit -m '<subject>'`.
  3. `status <plan>` — prints a `## Status` block showing each task (checked / running / blocked) and the track that owns it, for the Lead to read at a glance.
  4. `finish <worktree>` — fast-forward merge, remove the worktree and branch.
  5. `log <plan> <N> --sha … --note …` — flip the checkboxes, note the change, name newly unblocked tasks; when a track's last task is logged, print `track <id> done — review: <base>...<head>` with the track-end review sentence and write its diff to `.rolepod/evidence/review/<feature>-<id>.diff` (a docs-only or one-code-task track prints `track <id> done` alone). `finish <worktree>` (once, at track end) merges the track and prints `ready now:` for each fan-in task it unblocked.

Test levels, printed in every brief: the task's Command runs after each edit and last before returning; the whole-repo suite runs once per release, by the Lead. A red `integrate` goes back to the task owner in a new dispatch — the Lead never repairs it.

## Other CLIs

The mode table above applies on every CLI whose hook API can carry it; Antigravity's deny-only API turns a `warn` into silence. Root `hooks/` is the one source; `build/render.sh` copies the shared scripts (and `hooks/lib/`) into each plugin tree, so there is no hand-kept mirror. The evidence gate and the edit-time hooks are Claude-only; every CLI keeps the private-docs deny.

| CLI | Registered | Evidence gate |
|---|---|---|
| Codex | `claim-verify-nudge`, `session-start` (+ `agent-sync`; runs the context loader and the lock), `session-lifecycle --unlock`, `block-subagent-commit`, `precommit-gate` (`ROLEPOD_LEAD_CLI=codex`), `subagent-core --cli codex`, `fix-loop-breaker` | no — private-docs deny + commit ban |
| Cursor | `project-context-loader` (`sessionStart`, + session lock), `precommit-gate` (`beforeShellExecution`, a translator around the shared gate), `stop-unlock` (`stop`, + route record) | no — private-docs deny |
| Antigravity | `session-start.sh` (`PreInvocation`, session lock), `pre-tool.sh` (`PreToolUse` `run_command` → shared gate), `stop-unlock.sh` (`Stop`) | no — private-docs deny |
| opencode | JS plugin: session lock, post-compact re-anchor, commit deny, the shared `fix-loop-breaker` behind a translator, route record | no — private-docs deny + agent `permission:` blocks (subagent commit / push / merge) |

- **Codex** — same event names and stdin JSON as Claude, so the shared scripts run verbatim. `agent-sync.sh` (SessionStart) copies the bundled role TOMLs into `~/.codex/agents/` and replaces only the rolepod block of `~/.codex/AGENTS.md` when the plugin version changes (`ROLEPOD_AGENT_SYNC_OFF=1` disables it). `subagent-core.sh --cli codex` (SubagentStart) adds the short agent protocol to built-in children (`default`, `explorer`, `worker`) when a spawn has no rolepod role file; `claim-verify-nudge` stays silent for a payload with an `agent_id`. Codex's PreToolUse sees every spawn (`spawn_agent`, or `collaborationspawn_agent` on V2); rolepod registers no spawn gate. Codex trusts hooks by hash: a new or changed hook is skipped until the user trusts it once with `/hooks` — a release that changes a hook needs a re-trust. `always-on-loader` and `worktree-guard` do not run there (`apply_patch` input carries no `file_path`).
- **Cursor** — camelCase events; stdin / stdout JSON, exit 2 denies; hook commands run with cwd = plugin root. Always-on core is `rules/always-on-core.mdc` (`alwaysApply: true`). Not portable: `fix-loop-breaker` (no exit code on `afterShellExecution`), `push-ref-check` (no informational channel before a shell command), `claim-verify-nudge` (`beforeSubmitPrompt` cannot inject context).
- **Antigravity** — `hooks.json` wraps the events in one name key (`{"rolepod": {...}}`); commands are relative to the `hooks.json` directory. A PreToolUse hook prints one deny object or nothing: `{}` denies, and any unknown field or non-zero exit blocks the tool. agy accepts no context field, so nothing reaches the model except a deny reason.
- **opencode** — one plugin file exports both the 1.x named plugin and the opencode 2 `default { id, setup }`. On opencode 2 the plugin runs in the shared background service (`process.cwd()` is `$HOME`; the directory comes from `ctx.location.directory`), so `install.sh` ends with `opencode service restart`. `unset OPENCODE_CONFIG_DIR` before verifying a global install from an Orca terminal.

## Installation

Hooks ship in the plugin tree (`~/.claude/plugins/rolepod/hooks/`) and are declared in its `hooks/hooks.json`. Re-running install is idempotent; migration steps strip legacy hook entries from `~/.claude/settings.json`.

```bash
claude plugin list                     # "rolepod" enabled
claude plugin details rolepod@rolepod  # Hooks line: UserPromptSubmit, SessionStart, PreToolUse, PostToolUse, Stop
```
