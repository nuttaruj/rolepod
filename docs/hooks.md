# Hooks reference

Rolepod's hooks are bash + python scripts in `hooks/` (canonical source). Each CLI adapter registers the ones its hook API can run. Every hook is self-guarded: a missing dependency, a non-git directory or bad stdin means a silent exit 0. The Lead never invokes them; they fire on their own.

**Design rule (v2.176.0).** A hook stays silent while the model follows the workflow. It speaks only on a real mistake. The evidence gate runs only on Claude, where its evidence is native (the transcripts). Deliberate evasion is out of scope by design: the hooks catch normal-flow mistakes, not a crafted bypass.

**Message shape (v2.92.0).** Every deny or nudge has three parts and nothing else:

1. **Fact** — what this call did, with its numbers (files, reviewers, stage names).
2. **Fix** — the exact change that makes the same call pass.
3. **Exception** — the escape hatch, always user-set or stated in the artifact.

The *why* — incidents, doctrine — lives in this file and in the hook's source comments, never in the message. No message literal is over 600 chars.

## Event coverage (Claude)

| Event | Matcher | Hooks |
|---|---|---|
| `SessionStart` | `startup\|resume\|clear\|compact` | `always-on-loader.sh`, `project-context-loader.sh`, `session-lifecycle.sh --lock` |
| `UserPromptSubmit` | — | `claim-verify-nudge.sh` |
| `PreToolUse` | `Edit\|Write\|MultiEdit` | `worktree-guard.sh`, `gate-reminder.sh`, `subagent-write-scope.sh` |
| `PreToolUse` | `NotebookEdit` | `subagent-write-scope.sh` |
| `PreToolUse` | `Bash` | `precommit-gate.sh`, `push-ref-check.sh`, `block-subagent-commit.sh` |
| `PreToolUse` | `Workflow` | `workflow-tier-nudge.sh` |
| `PostToolUse` | `Workflow\|Agent` | `dispatch-auto-log.sh` |
| `PostToolUse` | `Bash` | `fix-loop-breaker.sh` |
| `Stop` | — | `session-lifecycle.sh --unlock` (+ route record) |

14 hook scripts, 16 registrations (`session-lifecycle.sh` and `subagent-write-scope.sh` register twice). `test-diff-lint.sh` is a helper the commit gate calls, not a registered hook. All hook Python runs `python3 -I`, so a stray `json.py` in the working directory cannot mute a hook.

**Cursor host guard (v2.130.1).** Cursor auto-imports Claude Code plugins and runs their `hooks/hooks.json`. Every Claude manifest command is therefore `[ -z "$CURSOR_PROJECT_DIR" ] && exec bash "${CLAUDE_PLUGIN_ROOT}/hooks/<x>.sh"; cat >/dev/null`: under Cursor the imported copy drains stdin and exits 0, and the Cursor-native plugin owns the host. Disable the imported copy on Cursor's Plugins page to stop its agents and skills loading twice.

## Per-hook reference

### `precommit-gate.sh` — PreToolUse `Bash`

The one hard checkpoint, at `git commit`.

- **Private docs (every CLI)** — a staged path under `docs/rolepod/` → deny. Details under Private working docs below.
- **High-risk diff (Claude only)** — a staged path matching the high-risk regex or `.rolepod/risk-paths` → deny until a strong reviewer has FINISHED since the last commit. Fix: the writer loop's `security-engineer` + a strong `universal-reviewer` (the external from the cross-family pool when it is on).
- **Session risk without a test (Claude only)** — the session edited high-risk code, wrote no test, and the staged diff is not high-risk → deny until a failing test is written or a reviewer has run.
- **Everything else** — silent. `test-diff-lint` findings, when present, print as one line. Each judged commit appends a `phase: gate` row that `rolepod-ticket log` copies into the plan.
- **What counts as high-risk** — the path regex (auth / billing / payment / migration / secret / crypto / token / oauth / webhook … — canonical list in the script, parity-pinned by lean-surface) plus `.rolepod/risk-paths`. Test-named files (`*.test.*`, `test_*.py`, `*_test.go` …) and prose files never count. A bare directory name (`tests/`, `spec/`) is not an exemption.
- **Evidence (Claude)** — counted since the last commit (a linked worktree follows its own HEAD reflog): the Lead transcript plus the session's sub-agent transcripts (60 newest), MAX with the phase-log `dispatch` rows of provenance `hook-auto`, plus anchored external passes. A write-mode brief never counts as a review; `qa-tester` never counts; a strong role dispatched at an explicit cheap or balanced model counts as a plain reviewer.
- **Satellite-first hold** — with the cross-family pool on, a high-risk logic diff clears on an internal strong reviewer only after the pool was tried (an anchored external pass, or an `external-fail` line). Pool off → nothing forced.
- **Which commit it judges** — `cd <dir> &&` and `git -C <dir>` move the diff directory; `bash -c`, `eval` and the common wrappers (`env`, `timeout`, `sudo` …) are unwrapped; `git add … && git commit` and `git commit -a` are judged on the working tree. Anything unresolvable falls back to the hook's cwd — never a new deny.
- **Review in flight** — a tree-rewriting git command (`stash`, `reset --hard`, `checkout`, `rebase`, `merge` …) while a detached cross-family job runs → one advisory line naming `--collect`.
- **Incidents** — a sub-agent-heavy day where high-risk commits cleared on stale day-1 evidence (window is now since the last commit); 672 green tests + an opus build still shipped 4 money bugs only the adversarial pass caught (high-risk needs a strong reviewer, not tests).
- **Bypass** — none needed: evidence auto-passes. `ROLEPOD_GATES_SOFT=1` silences the whole gate, private-docs deny included (logged). `ROLEPOD_GATES_HARD=1` turns a normal logic commit into a block that clears on a test edit or a reviewer. Legacy markers (`ROLEPOD_GATES_PASSED=1`, `[gates: pass]`) do nothing without evidence.

### `gate-reminder.sh` — PreToolUse `Edit|Write|MultiEdit` (Claude)

- **Effect** — on a high-risk path, ONE line and only when the commit would block now: fact (high-risk edit, 0 strong reviewers since the last commit) → Fix (the writer loop's `security-engineer` + strong `universal-reviewer`, or the external when the pool is on, must finish before commit) → Exception (user-set bypass only). Every other edit → silent.
- **In-flight lines** — a live detached cross-family review whose diff holds the edited file → `⏸ REVIEW IN FLIGHT` (the job reads the tree live; editing now makes its verdict an artifact). A live `--kind implement` job and an edit outside its allowed paths → `⏸ EXTERNAL IMPLEMENT IN FLIGHT` (that edit is reverted when the job returns).
- **Incident** — edit-time hard blocks once pushed a user to set `ROLEPOD_GATES_SOFT` for good (33 high-risk edits in a day, 116 unreasoned bypasses), which silenced the commit gate too; this hook only informs.
- **Bypass** — `ROLEPOD_GATES_SOFT=1` silences it.

### `block-subagent-commit.sh` — PreToolUse `Bash` (Claude, Codex)

- **Commit ban** — a sub-agent (`agent_id` set) running `git commit` / `git push` / `gh pr create` / `gh pr merge` / `git reset --hard` / `git push --force` → deny. The Lead owns version-control state. Wrapped forms (`timeout 300 git commit`, `xargs git commit`) are caught; a pure-output head (`echo`, `printf`) and a data heredoc are not.
- **Cannot-wait rule (Claude)** — a sub-agent Bash call with `run_in_background: true`, or a cross-family gate (`--kind …` without `--detach`, or `--collect`) with no `timeout` → deny. No completion notice ever reaches a sub-agent.
- **Incidents** — a `backend-developer` committed past the QA floor after marking COMPLETED; a task owner idled its whole budget waiting on a backgrounded gate.
- **Bypass** — none.

### `subagent-write-scope.sh` — PreToolUse `Edit|Write|MultiEdit|NotebookEdit` (Claude)

A sub-agent writes only what its role owns.

| Class | `agent_type` (namespace stripped) | May write |
|---|---|---|
| generic | `general-purpose`, `default`, `claude`, `workflow-subagent` (a bare Workflow `agent()`) | nothing in the product tree |
| test-only | `qa-tester`, `security-engineer` | test paths (`tests/`, `__tests__/`, `fixtures/`, `e2e/`, RSpec `spec/`, `*.test.*`, `*.spec.*`, `test_*.py`, `conftest.py`, test-runner config …) + markdown |
| read-only | `universal-reviewer`, `scout` | markdown only |

- **Effect** — deny (fact → Fix → Exception per class); the sub-agent returns the finding and the Lead dispatches the owning role. A `phase: write-scope` row lands in the phase-log. Owning roles, the Lead, an unknown `agent_type`, OS temp roots and scratch / evidence paths (`scratchpad/`, `.rolepod/`, `.claude/agent-memory/`, `docs/rolepod/`) pass.
- **Doctrine pair** — the agent protocol says a nested dispatch goes only to the rolepod role the brief or the Writer loop names; this hook is the backstop when it does not.
- **Incident** — 16 of 31 `general-purpose` dispatches edited product code with no role doctrine; `qa-tester` wrote 99 non-test product files.
- **Not enforced** — an owning role drifting into another domain (the brief's Files allowed bounds it); a write through the shell (doctrine: edit tools only).
- **Bypass** — `ROLEPOD_ALLOW_OUT_OF_SCOPE_WRITE=1` (user-set, logged).

### `worktree-guard.sh` — PreToolUse `Edit|Write|MultiEdit` (Claude)

- **Per-file deny** — a live sibling session in the same worktree already edited this exact file → deny, pointing at `EnterWorktree` then `git worktree add`. No sibling, or a different file → silent. A file is recorded as this session's only on the pass path, so a blocked attempt never claims it.
- **Self-do nudge (v2.116.0)** — the Lead (no `agent_id`) edits product code after its own routing line with no writer-role dispatch since: route R2 → at the first edit; route R3/R4 → at 6 edits. One line per route. R2: go to a task owner on main from the 3-5 line checklist. R3/R4: brief the Owner the map names; the Lead reads the decision brief and spot-checks one claim. Exception: the user said self-do, or the change is R1-sized. `ROLEPOD_NUDGE_OFF=1` silences it.
- **Incident** — two Claude sessions on one worktree stomped each other's edits.
- **Bypass** — `ROLEPOD_ALLOW_SHARED_WORKTREE=1` (intentional shared session).

### `workflow-tier-nudge.sh` — PreToolUse `Workflow` (Claude)

A Workflow `agent()` call defaults to the Lead's model and no frontmatter can change that, so this hook reads the script before it runs. Two denies, neither yields:

- **`bare-fanout`** — under a strong-class or unknown Lead, a fan-out `agent()` call (interpolated label, or inside `.map(` / `pipeline(` / `Array.from(` / a loop) with no tier. A tier is a `model:` or an `agentType:` that pins one (a rolepod role; a variable counts); a platform `agentType:` such as `general-purpose` pins nothing. Fix: pin every fan-out — sweep → cheap or `rolepod:scout`, build and per-item verify → balanced, the ONE judge → strong.
- **`bare-writer`** — under any Lead, an `agent()` with no `agentType:` on a stage whose name says it writes (Implement / Build / Fix / Integrate / Migrate / Refactor / Patch / Scaffold / Write). Fix: `agentType: 'rolepod:<role>'`. Without it `subagent-write-scope` blocks the first write minutes into the run.
- **Lead class** — the family word of the Lead's last transcript turn (haiku = cheap, sonnet = balanced, opus / fable / mythos = strong, else unknown).
- **Logging** — each deny appends a `phase: dispatch-gate` row (a denied fleet never reaches PostToolUse).
- **Incidents** — six fleets in one day ran at opus/fable with a nudge ignored; a role-less writing agent worked 96 turns before its first write was blocked.
- **Bypass** — `ROLEPOD_GATES_SOFT=1` turns a deny into a nudge (logged); `ROLEPOD_NUDGE_OFF=1` silences the hook.

### `dispatch-auto-log.sh` — PostToolUse `Workflow|Agent` (Claude)

- **Effect** — one `phase: dispatch`, `provenance: hook-auto` row per dispatch in `<git-root>/.rolepod/evidence/phase-log.jsonl`: tool, `agent_type` or workflow name, `model` (explicit value, `opus` for a model-less strong role, else `inherit`), `lead_model` / `lead_class`, model and effort overrides, `tier_mix` (only agentTypes that render a pin count as tiered). The commit gate reads these rows as its nested-reviewer backstop; `rolepod-stats` reads them for the dispatch and fleet-cost sections.
- **Incident** — the manual "log every dispatch" rule was never followed by the model that wrote it.
- **Bypass** — none (append-only, fail-open).

### `fix-loop-breaker.sh` — PostToolUse `Bash` (Claude, Codex, opencode)

- **Effect** — fingerprints the whitespace-normalized command and counts consecutive non-zero exits per session; a passing run resets it. At the 3rd consecutive failure of the same command → one note: stop fixing and go to `debug-issue`'s Second opinion step (hypothesis ledger → second opinion → escalate). Advisory, never blocks. A user cancel, an undetectable exit code or a changed command is not counted.
- **Incident** — a weaker Lead looped a failing fix for many rounds while the prose stop rule sat in context; counting its own attempts is what it could not do.
- **Bypass** — none (advisory).

### `push-ref-check.sh` — PreToolUse `Bash` (Claude)

- **Effect** — a real `git push` that would publish 2 or more commits (`@{push}..HEAD`, or the remote's default branch when there is no upstream) → names each commit and asks you to confirm each is yours or cleared by its author. One commit → silent. Never denies.
- **Incident** — in a shared worktree another session's local merge rode out on an unrelated push.
- **Bypass** — none (informational).

### `claim-verify-nudge.sh` — UserPromptSubmit (Claude, Codex)

- **Route nudge (v2.98.0)** — a commission-shaped prompt while the newest `phase: route` line predates the previous prompt → one `⟂ route:` line asking for the R0-R4 tier before the first edit. A question-shaped prompt and a harness background-task notification (`<task-notification>`) are not commissions and never get it. Incident: 199 requests, 0 router invocations in one project.
- **Auto-resume (v2.100.0)** — the harness's "continue from where you left off" prompt is a resume, not a user decision: a turn that ended at a question is restated, never continued into new scope.
- **Context-bloat note** — the last turn's context crosses 500k tokens → one Lead-facing note (sweeps go to `rolepod:scout`; mention `/compact` or a fresh session to the user once); re-arms only after the context drops under the line. Incident: a 12-day session re-read 350-900k tokens every turn.
- **Bypass** — `ROLEPOD_NUDGE_OFF=1` silences the whole hook.

### `session-lifecycle.sh` — SessionStart `--lock` / Stop `--unlock` (Claude, Codex)

- **`--lock`** — writes `~/.rolepod/session-locks/<sha256(worktree)>/<session_id>.lock`; a live sibling lock (< 30 min) → one warning suggesting `git worktree add`. Stale locks (> 30 min) are swept in every worktree's lock dir. The lock dir is shared by every CLI, so a Claude and a Codex session on one checkout see each other.
- **`--unlock`** — removes this session's lock and its `.files` registry (releasing what `worktree-guard` recorded), then runs the route record.
- **Route record (v2.105.0)** — `lib/route_check.py --record` reads the finished turn's assistant text and, when it holds a routing line at line start (`Route: R2 …` / `Tier: R3 …` / the arrow form), appends one `phase: route` row. Fenced code, placeholders and ranges (`R0-R4`) are ignored. Every CLI records it from its own transcript (Cursor `stop-unlock.sh`, agy `stop-unlock.sh`, opencode from the plugin). Incident: the manual route append was written 0 times across every product repo.
- **Bypass** — `ROLEPOD_ALLOW_SHARED_WORKTREE=1` silences the warning.

### `project-context-loader.sh` — SessionStart (Claude, Codex, Cursor)

- **Effect** — repo name, branch, dirty count, the last 5 commits, hot files (7 days), the last phase-log line, and an **Open plan** pointer: the newest `docs/rolepod/plans/*.md` that has at least one checked AND one unchecked box (a 0-done plan is never shown).
- **Other CLIs** — where `session-lifecycle` does not run, this loader registers the session lock and adds the sibling warning.
- **Cross-family** — no pool file and a second CLI installed → one context line naming `rolepod-cross-family --setup`, never a question.
- **Bypass** — none (context only).

### `always-on-loader.sh` — SessionStart (Claude)

Emits `hooks/always-on-core.md` (identity, precedence, verify-first, simplest-viable, code search, communication, risky actions, hard stops; rendered from `always-on-core.md.tmpl` + `core/fragments/`) as `additionalContext`. A Claude plugin has no other always-on surface, which is why the plugin install writes nothing into `~/.claude/CLAUDE.md`. Other CLIs load the same core natively (`AGENTS.md`, `rules/*.mdc`). Missing core file → silent.

### `test-diff-lint.sh` — helper (called by `precommit-gate.sh`)

Warn-only grep of the staged diff: focus / skip markers added, deleted test cases, snapshots refreshed with no test-logic change, DB mocks under integration / e2e paths, a literal calendar date under a test path. Findings print as one line at commit. A clean lint never means the tests are good: whether expected values came from the spec or from current output is a human judgment.

## Removed in v2.176.0

| Removed | Reason |
|---|---|
| Commit gate SOFT line: diff counts, "reviewers since last commit", the reviewer ask, the `S1-S5 / T1-T6 / F1-F5` advisory | normal-flow noise — it fired on every commit, including plan tasks whose review is the combined one before release |
| `AUTO-CAREFUL` banner on every high-risk edit | normal-flow noise — careful mode was removed in v2.171.0; the one would-block line replaces it |
| `T-gate violation`, the S/T/F list and "preferred" in the deny text | normal-flow noise — the deny now names only what clears it |
| Money-term content check (refund / payout / chargeback / settlement in added lines) | normal-flow noise — it flagged UI labels, i18n values and rendered prose (blocked this repo at v2.175.0) |
| Edit ledger: `hooks/edit-ledger.py`, `.rolepod/evidence/edits.jsonl`, every writer and reader | platform twin — the evidence is native only on Claude |
| `dispatch-proof` rows: Codex `subagent-model-log.sh`, Cursor `dispatch-log.sh`, agy `model-log.sh`, the opencode task hook, the cross-family runner | platform twin — `rolepod-stats` still reads old rows |
| The evidence gate on Codex, Cursor, Antigravity and opencode (the gate's lib-less branch included) | platform twin — parity is skills + workflow; those CLIs keep the private-docs deny |
| Cursor `gate-reminder.sh` (`preToolUse` and `postToolUse`); Codex `apply_patch` → `gate-reminder.sh` | platform twin |
| `block-subagent-commit.sh` shell-write rule (`bash_write_paths()`, its ledger rows, the synthesized write-scope check; the Codex copy of `subagent-write-scope.sh`) | dead path — it fed the removed ledger; "edit tools only" stays doctrine |
| Fleet gate `no-tier`, `single-tier`, `no-strong-judge`, `strong-spread`, `named-downgrade`, the loop valve, the low-Lead nudge, the `// tier-reason:` escape | normal-flow noise — two denies cover the measured cases |
| Fleet gate on `Agent`: the `updatedInput` → `opus` floor and the downgrade nudge | dead path — strong roles render `opus` in frontmatter since v2.104.0 |
| `dispatch-auto-log` `floor: applied` value | dead path — nothing lifts a model any more |

## Bypass envs

| Env | Effect | When |
|---|---|---|
| `ROLEPOD_GATES_SOFT=1` | Commit gate silent (private-docs deny included); fleet denies become nudges; `gate-reminder` silent | Iterating on rolepod's own doctrine for one session. Set permanently it switches off every hard checkpoint |
| `ROLEPOD_GATES_HARD=1` | A normal logic commit blocks until a test edit or a reviewer | A repo that wants every commit gated |
| `ROLEPOD_ALLOW_OUT_OF_SCOPE_WRITE=1` | `subagent-write-scope` passes | One dispatch that must write outside its class (a test helper beside source) |
| `ROLEPOD_ALLOW_SHARED_WORKTREE=1` | `worktree-guard` and the sibling warning pass | Intentional shared session (read-only review, coordinated file ownership) |
| `ROLEPOD_NUDGE_OFF=1` | `claim-verify-nudge`, the self-do nudge and `workflow-tier-nudge` silent | A session that does not want nudges |
| `ROLEPOD_GATES_PASSED=1` | Legacy; nothing without evidence | Never prescribed — permission layers read `ENV=1 git commit` as gate circumvention |

Apply them per session, never globally. **They are the user's hand only:** a model that meets a gate conflicting with an instruction surfaces the conflict with options; it never sets a bypass itself. Every used bypass appends `{"ts","hook","var","reason"}` to `<git-root>/.rolepod/evidence/bypass.log`, the reason taken from `ROLEPOD_BYPASS_REASON` (default `"unreasoned"`); `rolepod-selftest` tags doctor and test probes so `rolepod-stats` counts them apart. `ROLEPOD_*` is rolepod's namespace; Claude Code's own behavior stays under `CLAUDE_CODE_*`.

## Cross-family pool — `.rolepod/cross-family` (v2.76.0)

Opt-in and off by default. `<git-root>/.rolepod/cross-family` (project) overrides `~/.rolepod/cross-family` (machine); no file or `none` = off.

```
[reviewer]
review = agy codex opencode stall=900   # default order for every kind; stall= is the silence budget (default 600 s)
consult = agy codex                     # per-kind order

[implement]
cli = codex claude                      # members that may WRITE a ticket (--kind implement, v2.139.0)
```

- **Members** — `codex`, `claude`, `agy`, `cursor`, `opencode` (a `gemini` line is skipped). List every CLI you use: only the Lead's own CLI is skipped at run time, so one file serves every Lead. The model family is recorded for information and never filters a member.
- **Setup** — never asked unprompted. When the user asks, the Lead runs `rolepod-cross-family --setup`, asks the review order then the implement order, and writes the file with `--setup review="…" implement=…`.
- **Time** — a member is killed when it goes SILENT for `stall` seconds (`--stall` > `stall=` > 600), not when it is slow; the wall-clock cap is runaway insurance only (review 7200 s detached / 600 s foreground, consult 300, critique 600). `--detach` runs the chain as a job under `.rolepod/evidence/external/jobs/<id>/`; `--collect <id>` waits, `--jobs` lists.
- **Refusals** — a partial-slice diff (its files have edits it does not contain) → exit 7, attach `git diff HEAD` or commit first (`--partial-ok` only when the user asked for the staged part); a second live review job → exit 8 until `--collect` or `--kill`.
- **Rounds** — the external runs once per R4 task, round 1 only; round 2+ is internal (`security-engineer` re-checks its own and the external's BLOCKER / MAJOR findings on a high-risk path, strong `universal-reviewer` the rest). A pre-existing issue on an untouched path is one note line and never drives the verdict.
- **At commit (Claude)** — see the satellite-first hold under `precommit-gate.sh`. Code only: a docs-only diff passes the gate at any size (docs are written, not reviewed — owner rule).

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

## Ticket helper — `rolepod-ticket` (v2.155.0)

`scripts/ticket.sh`, on PATH after install and shipped in every plugin tree, turns a plan task's mechanics into two Lead calls:

- **`start <plan> <N> [--base <branch>]`** — runs `plan-lint`, writes the owner brief, creates the worktree + branch, prints the dispatch line and a `ship:` line with `<commit gate>` / `<subject>` / `<note>` to fill in. Idempotent.
- **The ship chain** — one Bash call after the owner returns; a red step stops it before the commit:
  1. `integrate <worktree> --brief <file> --gate '<cmd>'` — fast-forward to the base, stage everything except `docs/rolepod/`, run the brief's Proof, then the gate.
  2. `git -C <worktree> commit -m '<subject>'`.
  3. `finish <worktree>` — fast-forward merge, remove the worktree and branch.
  4. `log <plan> <N> --sha … --note …` — flip the checkboxes, note the change, name newly unblocked tasks; once every role-owned task is done, print the combined-review range and write its diff to `.rolepod/evidence/review/<plan-slug>.diff`.
- **`fleet <plan> [--base] [--max <N>] [--gate '<cmd>']`** (Claude) — runs `start` for every ready role-owned task and prints one `{scriptPath, args}` for `scripts/ticket-fleet.js`. `--gate` runs once first (red → no worktree created); a task already in flight is skipped; a per-plan lock stops two overlapping runs.

Test levels, printed in every brief: the task's Command runs after each edit and last before returning; the whole-repo suite runs once per release, by the Lead. A red `integrate` goes back to the task owner in a new dispatch — the Lead never repairs it.

## Other CLIs

Root `hooks/` is the one source; `build/render.sh` copies the shared scripts (and `hooks/lib/`) into each plugin tree, so there is no hand-kept mirror. The evidence gate and the edit-time hooks are Claude-only; every CLI keeps the private-docs deny.

| CLI | Registered | Evidence gate |
|---|---|---|
| Codex | `claim-verify-nudge`, `project-context-loader`, `session-lifecycle --lock/--unlock`, `agent-sync`, `block-subagent-commit`, `precommit-gate` (`ROLEPOD_LEAD_CLI=codex`), `fix-loop-breaker` | no — private-docs deny + commit ban |
| Cursor | `project-context-loader` (`sessionStart`, + session lock), `precommit-gate` (`beforeShellExecution`, a translator around the shared gate), `stop-unlock` (`stop`, + route record) | no — private-docs deny |
| Antigravity | `session-start.sh` (`PreInvocation`, session lock), `pre-tool.sh` (`PreToolUse` `run_command` → shared gate), `stop-unlock.sh` (`Stop`) | no — private-docs deny |
| opencode | JS plugin: session lock, post-compact re-anchor, commit deny, the shared `fix-loop-breaker` behind a translator, route record | no — private-docs deny + agent `permission:` blocks (subagent commit / push / merge) |

- **Codex** — same event names and stdin JSON as Claude, so the shared scripts run verbatim. `agent-sync.sh` (SessionStart) copies the bundled role TOMLs into `~/.codex/agents/` and replaces only the rolepod block of `~/.codex/AGENTS.md` when the plugin version changes (`ROLEPOD_AGENT_SYNC_OFF=1` disables it). Codex trusts hooks by hash: a new or changed hook is skipped until the user trusts it once with `/hooks`. `always-on-loader` and `worktree-guard` do not run there (`apply_patch` input carries no `file_path`).
- **Cursor** — camelCase events; stdin / stdout JSON, exit 2 denies; hook commands run with cwd = plugin root. Always-on core is `rules/always-on-core.mdc` (`alwaysApply: true`). Not portable: `fix-loop-breaker` (no exit code on `afterShellExecution`), `push-ref-check` (no informational channel before a shell command), `claim-verify-nudge` (`beforeSubmitPrompt` cannot inject context).
- **Antigravity** — `hooks.json` wraps the events in one name key (`{"rolepod": {...}}`); commands are relative to the `hooks.json` directory. A PreToolUse hook prints one deny object or nothing: `{}` denies, and any unknown field or non-zero exit blocks the tool. agy accepts no context field, so nothing reaches the model except a deny reason.
- **opencode** — one plugin file exports both the 1.x named plugin and the opencode 2 `default { id, setup }`. On opencode 2 the plugin runs in the shared background service (`process.cwd()` is `$HOME`; the directory comes from `ctx.location.directory`; an env flag reaches it only via `ROLEPOD_GATES_SOFT=1 opencode service restart`), so `install.sh` ends with `opencode service restart`. `unset OPENCODE_CONFIG_DIR` before verifying a global install from an Orca terminal.

## Installation

Hooks ship in the plugin tree (`~/.claude/plugins/rolepod/hooks/`) and are declared in its `hooks/hooks.json`. Re-running install is idempotent; migration steps strip legacy hook entries from `~/.claude/settings.json`.

```bash
claude plugin list                     # "rolepod" enabled
claude plugin details rolepod@rolepod  # Hooks line: UserPromptSubmit, SessionStart, PreToolUse, PostToolUse, Stop
```
