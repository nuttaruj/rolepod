# Hooks reference

Rolepod ships a family of **core bash hook scripts** in `hooks/`. Each CLI adapter declares the applicable ones in a plugin/extension `hooks/hooks.json` — Claude, Codex, Gemini, and Cursor all use the same `hooks/hooks.json` form (Cursor uses camelCase event names; the others use PascalCase). All hooks are **self-guarded** — silent no-op when a dependency is missing.

Lead does not invoke these manually. They fire automatically.

**Message shape (v2.92.0).** Every deny or nudge a hook emits is three parts and nothing else: the **fact** of this call (with its numbers — agent count, Lead model, stage names, diff size), the **fix** (the exact change that makes the same call pass), and the **exception** (the escape hatch, always user-set or stated in the artifact). The *why* — measured history, doctrine, the incidents that motivated a rule — lives in this file and in the hook's source comments, never in the message: the model cannot bypass a deny, so it never needed convincing, and every clause of persuasion was paid for on every fire. `tests/static/hook-message-lean.sh` holds the line — no `measured:` / `observed:` vocabulary in message text, no message literal over 600 chars.

## Hook categories — All core (no add-on hooks)

| Category | Hooks | Purpose |
|---|---|---|
| **Always-on** | `always-on-loader` | Inject the rolepod always-on judgment core as SessionStart context |
| **Output shape** | `terse-loader` | Inject the opt-in terse-output layer as SessionStart context, only when the user's flag file exists |
| **Enforcement** | `block-subagent-commit`, `subagent-write-scope`, `gate-reminder`, `precommit-gate` | Hard / soft blocks on discipline violations (high-risk path, sub-agent commit) |
| **Publication** | `push-ref-check` | Show every commit a `git push` would publish when the ref carries more than one |
| **Context** | `project-context-loader` | Inject git state at SessionStart |
| **Session safety** | `session-lifecycle`, `worktree-guard` | `session-lifecycle`: SessionStart lock + Stop unlock; every worktree's lock dir is swept of >30 min locks at SessionStart (v2.147.1). `worktree-guard`: hard-blocks an edit only when a live sibling owns that exact file — disjoint/solo edits flow free |
| **Answer-path** | `claim-verify-nudge` | Soft nudges at the one hookable moment before a prompt is answered: a commission-shaped prompt with a stale route gets a router-tier reminder (`⟂ route:`), and a harness auto-resume prompt is restated rather than continued into new scope. Since v2.49.0 also the **context-bloat check**: reads the last turn's context size from the transcript and, on crossing 500k tokens adds one note, and again only after a /compact brings the context under the line and it crosses once more (v2.119.1; 200k per 200k bucket before) per session — `additionalContext` for the Lead only (delegate reads to a scout; in THIS turn's closing line mention /compact or a fresh session to the user once, then never again until a new line arrives — the user-facing `systemMessage` was removed in v2.49.1 as friction). Measured need: a 12-day session ran every turn at 350-900k tokens; each turn re-reads all of it — one grep sweep = 31 turns × 558k ≈ $9. Claude/Codex `UserPromptSubmit`, Gemini `BeforeAgent`; soft, never blocks |

All core hooks register on every Claude install. rolepod-brain and GitNexus integrate via their own plugins/CLI, not rolepod hooks.

PR 6 dropped `verify-reminder.sh` (PostToolUse Edit/Write per-edit nag). The same discipline lives in:
- skill `check-work` — Iron Rule + evidence-required output contract
- `precommit-gate.sh` — hard-blocks commit on high-risk + zero tests
- skill `using-rolepod` — Verify phase exit gate

A per-edit reminder hook duplicated all three without enforcement teeth — so it was removed instead of replicated.

## Event coverage

| Event | Matcher | Hooks |
|---|---|---|
| `SessionStart` | `startup\|resume` | `always-on-loader.sh`, `terse-loader.sh`, `project-context-loader.sh`, `session-lifecycle.sh --lock` |
| `UserPromptSubmit` | (no matcher) | `claim-verify-nudge.sh` |
| `PreToolUse` | `Edit\|Write\|MultiEdit` | `worktree-guard.sh`, `gate-reminder.sh`, `subagent-write-scope.sh` |
| `PreToolUse` | `NotebookEdit` | `subagent-write-scope.sh` |
| `PreToolUse` | `Bash` | `precommit-gate.sh`, `push-ref-check.sh`, `block-subagent-commit.sh` |
| `PreToolUse` | `Workflow\|Agent` | `workflow-tier-nudge.sh` |
| `PostToolUse` | `Workflow\|Agent` | `dispatch-auto-log.sh` |
| `Stop` | (no matcher) | `session-lifecycle.sh --unlock` (+ route record, v2.105.0) |

### Cursor host guard (v2.130.1)

Cursor auto-imports every Claude Code plugin from `~/.claude/plugins/installed_plugins.json` and runs its `hooks/hooks.json` with the Claude event names mapped (`PreToolUse` → `preToolUse`, …). On a machine that also carries the Cursor-native rolepod plugin (`install.sh --target=cursor`) that ran two hook sets per tool call. Every command in the Claude manifest is therefore `[ -z "$CURSOR_PROJECT_DIR" ] && exec bash "${CLAUDE_PLUGIN_ROOT}/hooks/<x>.sh"; cat >/dev/null` — Cursor sets `CURSOR_PROJECT_DIR` for hook processes only (IDE 3.20 / agent CLI 2026.09, verified 2026-09-16), so under Cursor the imported copy drains stdin and exits 0 while the Cursor-native rule + 3 hooks own the host. On Claude Code and every other CLI the guard is a shell builtin and `exec` hands the process to the script: no extra process, exit status intact. The imported copy's agents and skills still load a second time — disable it on Cursor's Plugins page if that matters. Guard: `tests/static/cursor-host-guard.sh`.

## Per-hook reference

### `claim-verify-nudge.sh` — UserPromptSubmit (core)

**Route nudge (v2.98.0)** — a commission-shaped prompt (fix / add / change / build … + Thai equivalents; claim-shaped analysis prompts and Thai questions excluded) while the repo's newest `phase:"route"` line is older than the previous user prompt (transcript tail; no transcript → 30 min) → one `⟂ route:` line asking for the R0-R4 tier before the first edit. Checker: `hooks/lib/route_check.py`. Not a git repo → silent. Measured need: 199 requests / 0 router invocations in one project.

**Route record (v2.105.0)** — the same checker writes the route line itself. At Stop (`session-lifecycle.sh --unlock` → `lib/route_check.py --record`) and again on the next commission prompt as a fallback (an interrupted turn has no Stop), it reads the finished turn's assistant text from the transcript tail, finds the routing line the router prescribes — two shapes, both at line start: a `Route:` / `Tier:` field (`**Route: R2 — reason**`, `Route: R2 (one file + test) → <skill> · <reason>` — a gloss in parentheses after the tier is fine — `Tier: R3 (multi-file)` inside the block) or the pre-2.105 arrow form (`→ <skill> · R2 · …`) — and appends `{"ts","phase":"route","tier","skill","provenance":"hook-auto"}` once per turn — a turn that already has a route line, manual or auto, is left alone. Ignored on purpose: fenced code, `<skill>` / `<reason>` placeholders, `R0-R4` / `R3/R4` / `R3 (multi-file) | R4 (high-risk)` ranges — a gloss between the two codes is tolerated — (quoted doctrine, not a decision), `R3-B`-style labels, and anything mid-line. Why no bare `R2 (…)` shape and nothing mid-line — measured on 164,410 assistant lines across every local session: real routes are the field form (14, all `**Route: R2 — …**`), the `Routing:` block appeared 0 times, the arrow one-liner 0, the 4 mid-line `· R2 ·` hits were Cloudflare R2 table rows, and the 34 bare line-start `R2` / `R3-B` lines were phase labels and review-finding numbers. A user prompt with no timestamp is still the turn boundary (the dedupe then keys on the routing message's own timestamp). Known residual (constructed, 0 in the corpus; qa-tester round 3): a single-backtick inline quote `` `Tier: R3` `` or a blockquote `> Tier: R3` at line start still records — the markdown prefix is allowed on purpose because the real form is `**Route: R2 — …**`; not worth a fourth regex round. Measured 2026-09-08: the manual append the router asked for since v2.98.0 was written 0 times across every product repo on this machine (7 lines in rolepod itself), so the nudge fired on every commission and `make stats` had no tier distribution; the same day a 1-file CSS change under ultracode ran a design panel, a 14-agent review and the full e2e suite twice with its R2 stated only in chat.

**Auto-resume (v2.100.0)** — the harness prompt after a usage-limit pause ("Please continue from where you left off") gets one line: it is a resume, not a user decision — a turn that ended at a question / breaker / decision brief is restated, never continued into new scope or a new review round; the route nudge skips it.

One more soft check rides the same event; no new registration.

- **Context-bloat check (v2.49.0)**: `session_state.py context-tokens` (input + cache_read + cache_creation of the last assistant turn) crossing 500k → one note; edge-triggered — the state file says "fired" while the context sits above the line and is removed on the first reading under it, so a /compact that brings it back under re-arms the one note (v2.119.1; 200k per 200k bucket until then — the long-context pricing knee, gone since Claude 4.6 bills the full 1M window at one rate). The Lead-facing line binds its user relay to THIS turn's close and forbids a repeat until a new line arrives — measured 2026-09-11: one session saw 2 hook lines and 43 Lead "/compact" mentions because "when the task is done" read as every turn's end (state in `~/.rolepod/ctx-nudge/<session_id>`): `additionalContext` telling the Lead every turn re-reads all of it — dispatch `rolepod:scout` for sweeps, and mention `/compact` / a fresh session to the user ONCE when the task is done (Lead-facing only since v2.49.1: the user-facing `systemMessage` nag was removed on request; the Lead raises it in its own words at a natural pause). Why here and not a hook of its own: the cost driver measured on a real project was the Lead's own re-reads (~90 % of spend), and no existing hook looked at `usage`.
- **Self-guards**: no transcript / no usage → context branch silent; empty prompt with a bloated context still emits the context note.
- **Bypass**: `ROLEPOD_NUDGE_OFF=1` — the early exit at the top of the hook, so it silences everything in this hook (route nudge, auto-resume, context-bloat, and the breaker / review-rounds reminder).

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

### `terse-loader.sh` — SessionStart (core, opt-in)

Deliver the opt-in terse-output layer. Kept separate from
`always-on-loader.sh` on purpose: a user who has not opted in pays zero
bytes, and a failure in one loader can never take the other down.

- **Opt in**: `touch ~/.claude/.rolepod-terse` — empty means `ultra`, the
  default since v2.130.0 (articles / filler / conjunctions dropped, each fact
  once, no decorative tables; identifiers, paths, counts and error text never
  abbreviated); write `lite` for full sentences with only filler and register
  dropped; anything unrecognised reads as ultra. Opt out: delete the file. The flag
  lives in `CLAUDE_CONFIG_DIR`, not the git root, because output shape is a
  property of the person reading, not of the project being read.
- **Effect**: reads `hooks/terse-core.md` beside the script (~1.7KB — lead
  with the result, drop the reading language's politeness register, numbered
  steps, flat error tone, a five-item display cap that explicitly never
  limits analysis or tool results) and emits it as SessionStart
  `additionalContext` behind a banner naming the flag and level.
- **The task always wins**: the layer yields to security warnings,
  destructive-action confirmation, "explain" requests, a third failed
  attempt, real ambiguity, and anything the harness mandates. Shape yields,
  substance never does.
- **Self-guards**: no flag → exits 0 with no output at all; core file missing
  or python failure → silent exit, never a partial payload.
- **Other CLIs, same flag**: Gemini folds the same check into its
  `session-start.sh`; Cursor ships `rules/terse.mdc` with
  `alwaysApply: false`; Codex, Antigravity and opencode carry a pointer in
  their entry doc that names the shipped `terse-core.md`.

### `push-ref-check.sh` — PreToolUse(Bash), informational

Show what a `git push` would actually publish. A push publishes the REF, not
the commit you just made: in a shared worktree another session's local merge
rides out on your push, which is a measured incident rather than a
hypothetical.

- **Fires**: a real `git push` in command position — `cd x && git push` counts,
  `echo git push` does not — and only when the push would publish **2 or more**
  commits. Pushing your own single commit is the common case and gets no line.
- **Effect**: names each commit on the range (`@{push}..HEAD`, or the remote's
  default branch when the branch has no upstream yet) and asks you to confirm
  each is yours or cleared for publication by its author.
- **Never denies.** The incident happened because nobody looked, not because
  someone looked and judged wrong, so the hook shows and stops there. Deciding
  whose commit is whose would need a sha-to-session ledger, and a rebase
  rewrites every sha — exactly the branch-per-worktree flow rolepod now
  recommends. A denying version waits for a measured "looked and still missed
  it" case.
- **Self-guards**: not a git repo, no `@{push}` that resolves, unparsable
  command → silent exit 0.

### `project-context-loader.sh` — SessionStart (core)

Inject git context at session start.

- **Effect**: `additionalContext` with repo name, branch, dirty count, recent commits (last 5), hot files (last 7 days).
- **State pointers (v2.102.0)**: the newest `docs/rolepod/plans/*.md` with unchecked steps (`done / open · next: Task N`), an open breaker ledger (or `N rounds, no ledger`) via the runner's `--rounds`, and the last phase-log line — the "read the progress file first" step of a long-running-agent harness, done for the Lead at startup / resume / compact.
- **Self-guards**: not in a git repo → silent; non-JSON failure → emits `{}`.
- **Concurrent-session soft-warn (Codex / Gemini / Cursor)**: on the CLIs that have no `session-lifecycle` hook, this loader also registers a lock in the neutral `~/.rolepod/session-locks/<sha256(worktree)>/` dir and appends a soft warning when a live sibling (any CLI, <30 min) is present. On Claude it skips this (detected via `CLAUDE_PROJECT_DIR`) because `session-lifecycle` already owns the warning — no double-fire. This is the soft-warn-everywhere floor; the hard `worktree-guard` gate remains Claude-only.
- **What this hook does not do**: no add-on detection, no vendor-tool recovery, no first-session nag, no external-reviewer banner. Add-on availability is documented in README + skills, never nagged per SessionStart.

### `session-lifecycle.sh --lock` — SessionStart (core)

Detect sibling Claude session(s) in the same worktree to prevent concurrent-edit stomp.

- **Effect**: write own lock to `~/.rolepod/session-locks/<sha256(worktree)>/<session_id>.lock`. If sibling locks (<30 min old) detected → warn + suggest `git worktree add` path. Auto-prune stale locks (>30 min) and their `.files` registry. The lock dir is CLI-neutral so Codex/Gemini/Cursor sessions (which warn via their SessionStart context-loader) are detected too.
- **Self-guards**: not in a git repo → silent; no sibling → silent.
- **Bypass**: `ROLEPOD_ALLOW_SHARED_WORKTREE=1` (for intentional read-only review sessions).
- **Pair**: same script `--unlock` on Stop (since v2.105.0 it also runs `lib/route_check.py --record`: the tier stated in the finished turn → one `phase:"route"` line in the phase-log); `worktree-guard.sh` enforces per-file at edit time (this hook only warns once at start).

### `gate-reminder.sh` — PreToolUse Edit/Write/MultiEdit (core)

High-risk edit guard (and, since v2.134.0, the edit-ledger writer — every edit tool call lands in `.rolepod/evidence/edits.jsonl`). Silent on normal code edits (PR 5 slim — the generic Q1-Q4 reminder lives in the always-on core / AGENTS.md / the using-rolepod skill, read once per session, not per edit).

Fires output ONLY when:
1. **High-risk path** (auth / authentication / authorization / billing / migration / secret / crypto / token / oauth / jwt / sso / saml / webhook / stripe / paypal / charge / invoice — illustrative; canonical regex in the script, parity-pinned by lean-surface) → soft warn + auto-Careful banner naming the R4 floor: `security-engineer` + ONE general strong pass (the pool's CLI in place of `universal-reviewer` when usable, else `universal-reviewer`).
2. **High-risk path + evidence gap** → the banner is prefixed with what the commit gate WILL require (`⛔ COMMIT WILL BLOCK — …`): 0 test edits since the last commit → write the failing test first; high-risk edits with 0 strong reviewers since the last commit → dispatch `rolepod:universal-reviewer` / `rolepod:security-engineer` before committing. **Warn-only, never a deny (v2.47.0)** — edit-time HARD blocks were the measured reason a user set `ROLEPOD_GATES_SOFT` for good (CourtBook: 33 high-risk edits in one day → 116 unreasoned bypasses), which then silenced the commit gate too. One hard checkpoint, at commit; this hook informs. Evidence window = since the last commit, Lead + subagent transcripts (same reader as the commit gate).

3. **Review in flight (v2.93.0)** — a detached cross-family job is still running (live pid under `.rolepod/evidence/external/jobs/`) and the edited file is in its attached diff (`+++ b/` paths from the job's `args`; attachments gone → the current `git diff HEAD` file list) → one advisory line (`⏸ REVIEW IN FLIGHT …`): the job reads the tree live, an early edit turns its verdict into an artifact and re-runs it. Never a deny; doctrine side = review-code §1 (the round ends when the last member returns; §6 starts on the merged list).

4. **External implement in flight (v2.139.0)** — the live job is `--kind implement` (its dir holds `allow`): an edit OUTSIDE the ticket's allowed paths gets `⏸ EXTERNAL IMPLEMENT IN FLIGHT: … is EDITING this tree — an edit outside the ticket's Files allowed made now (this one included) is reverted when the job returns (a copy is kept under the job's .reverted/)`; edits inside the scope stay silent. A new file in a not-yet-existing directory resolves through its nearest existing ancestor (symlinked roots included).

- **Self-guards**: docs / lockfiles / non-high-risk code → silent.
- **Bypass**: `ROLEPOD_GATES_SOFT=1` silences the would-block wording (banner stays) and the in-flight line.

### `worktree-guard.sh` — PreToolUse Edit/Write/MultiEdit/NotebookEdit (core)

- **Self-do nudge (v2.116.0; R2 lane added)**: on an edit to a product-code file by the Lead (no `agent_id`), `lib/session_state.py selfdo-state` scans the transcript once — the newest routing line the Lead wrote (`Route: R3 …` / `Tier:` / arrow form, the shapes `route_check.find_route` accepts), then every Edit-tool call on product code (a non-test code file, or an infra file the Owner map assigns to devops-sre — CI workflow, Dockerfile / compose, vercel / wrangler / fly / railway config, `deploy/` `infra/` `terraform/`, release scripts; v2.117.0) and every writer-role dispatch (`WRITER_ROLE_AGENTS`: the ten owner roles of the plan-template domain map; Agent/Task `subagent_type` or Workflow `agentType`) at or after it. Route R2 + ≥ 1 Lead product edit + 0 writer dispatch, or route R3/R4 + ≥ 6, → one `additionalContext` line, ONCE per route (marker `<session_id>.selfdo` holds the route timestamp): R2's line names its own path (fact → Fix: R2 goes to a task owner on main from the 3-5 line checklist → Exception: the user said self-do, or this is R1-sized); R3/R4 keeps the dispatch-to-Owner wording (fact → Fix: task brief to the Owner the map names → Exception: the user said self-do, or this is R1-sized). Never on R1, a subagent's edit, a test / doc / config target, or without a routing line; `ROLEPOD_NUDGE_OFF=1` silences. Guard: `tests/static/selfdo-nudge.sh`.
- **Touched-files registry**: the per-session registry that backs the worktree-collision check below also tracks whether a file was edited before this session — no nudge rides on it anymore (the reuse-ladder nudge was cut v2.164.0; the always-on core states the ladder every session already).

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

v2.134.1: `git add … && git commit` and `git commit -a` in ONE command are gated on the working tree (tracked changes vs HEAD + untracked files) — at hook time nothing is staged yet, and that shape used to pass on every CLI (measured live).

Escalates to HARD block at `git commit` time when the session touched high-risk code but never produced a test edit.

- **Effect** (evidence split by risk since v2.46.0): HIGH-RISK diff (path regex OR money-movement terms in staged added lines of non-test, non-prose files — `.md/.mdx/.txt/.rst/.adoc` never count as money logic, and a `-` line in `.rolepod/risk-paths` excludes a path from the content check exactly as from the path regex) → auto-pass ONLY on ≥1 strong-class adversarial reviewer dispatch (security-engineer / universal-reviewer, and NOT explicitly dispatched at a cheap/balanced model — a model-less dispatch counts because the role renders `model: opus` (v2.104.0) and `workflow-tier-nudge.sh` also lifts it on a low Lead); other HARD blocks → ≥1 test edit or ≥1 reviewer dispatch. Every auto-pass logs to `~/.rolepod/gate-bypass.log` (read by `make stats`) + additionalContext note; insufficient evidence → `permissionDecision: deny`.
- **Evidence window (v2.47.0)**: counted **since the last commit** (`git log -1 --format=%ct` — git's clock, unaffected by denied attempts, hook-less commits, or a 12-day session; no commit yet → whole session) across the Lead transcript **plus the session's subagent transcripts** (`<session>/subagents/**/agent-*.jsonl` — Agent tool and Workflow fleets, mtime inside the window, 60 newest). Measured need: a CourtBook session where session-cumulative evidence from day 1 (`tests=303 strong=2`) would have cleared every commit on day 12, while the tests the Workflow agents actually wrote (79–566 edits/day) were invisible to the Lead-only reader.
- **Follows the commit's directory (v2.153.0)**: `cd <dir>` segments that precede the `git … commit` invocation in the same command (`&&`, `;`, newline, a subshell paren), then `-C <dir>` on that invocation itself (relative to the directory so far), resolve the directory every diff-reading call uses (`--numstat`, the untracked listing, the private-docs / content-risk / logic-line scans, `test-diff-lint.sh`) — a commit run as `cd <worktree> && git commit` or `git -C <worktree> commit` is judged against THAT directory's staged diff, not the session checkout's (previously silent: an empty session index skipped the gate outright, or a dirty one gated the wrong diff). Unresolvable (`cd "$VAR"`, `cd -`, a missing directory, a directory that is not a git work tree, a parse error) always falls open to the hook's own cwd — exactly today's behavior, never a new deny; it never follows a shell variable, `pushd`, `env -C`, a function or an alias. `.rolepod/` config, phase-log, edit-ledger and cross-family evidence keep resolving from the hook cwd (falling back to the diff directory's toplevel only when the hook cwd itself is not a git repo). In a linked worktree (`--git-dir` ≠ `--git-common-dir`), "since the last commit" follows the worktree's own HEAD reflog instead of its last commit — a `git merge --ff-only main` there is not a commit and must not drop a reviewer dispatched before it.
- **Review in flight (v2.93.0)**: a tree-rewriting git command (`stash` except `list`/`show`, `reset --hard|--merge|--keep`, `checkout`, `switch`, `restore`, `rebase`, `merge`, `cherry-pick`, `clean`, `pull`) while a detached cross-family job is live → one advisory `additionalContext` line naming the job and `--collect`; never a deny. The running-job walk is `xfam_running_job()`, shared with the commit hold.
- **SOFT line (v2.95.0)**: carries `reviewers since last commit: N`; a logic diff with 0 asks for one read-only universal-reviewer pass (review-code §1 R2 floor — the author never reviews own logic); an R1-shaped diff (1 code file, ≤5 logic lines — v2.153.0) gets the count only, since a user-facing string edit is R1 in the router (v2.96.0). Advisory.
- **The count is about code (v2.153.0)**: `logic` counts non-comment, non-blank lines of non-prose files only — prose riding along in a mixed diff is not logic (a quoted non-ASCII path and a deleted prose file included). On the SOFT line a line that is ONLY a version field (`"version": "1.2.3"`, `version = "1.2.3-rc.1"`, `version: v1.2.3` — semver-shaped, nothing after it) is a release bump, not logic; `version: 1.2.3;run()` still counts. Generated files leave the SOFT count too (v2.153.2): a path git marks `linguist-generated` (`.gitattributes` or `.git/info/attributes` — rendered copies, `dist/`, codegen, snapshots) and the standard lockfiles (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Cargo.lock`, `poetry.lock`, `go.sum`, …) — a dependency add or a docs change with rendered copies no longer asks for a reviewer; a path git quotes, or a commit run from a subdirectory, fails to match and keeps counting (one extra ask, never a skipped one). The HARD side keeps the wider count: version lines and generated files on a risky path are still a logic-bearing diff for the cross-family hold. The ask names its exception: the task owner already had the diff reviewed, or it is config / generated copies / message text.
- **Self-guards**: non-commit Bash → silent; non-high-risk session → silent. Test-**named** staged files (`*.test.*` / `*.spec.*`, `test_*.py`, `*_test.go`, `*_spec.rb`, `*Test.java`) do not trigger the path regex (v2.85.2) — a test-only commit under `tests/auth/` is the QA-automation deliverable, and the same file is already exempt at edit time; a bare directory name (`tests/`, `spec/`, `e2e/`) is NOT an exemption, so `api/specs/auth.yaml` and `tests/fixtures/seed_auth_users.py` still block, and a mixed diff blocks on its production path. The money content-check also excludes these paths, so money logic living inside a test-named file is an accepted blind spot.
- **Nested-reviewer backstop (v2.144.0)**: on Claude the reviewer count is MAX(transcript scan, phase-log `dispatch` rows since the last commit) — never a sum. The transcript scan already sees one nesting level (a task owner's own Agent call sits in its transcript under `<session>/subagents/`) but caps at the 60 newest subagent transcripts; the append-only phase-log backstops that drop. A row counts only with provenance `hook-auto`; a strong-role row whose model is a named low-class downgrade counts as a plain reviewer; the model-class check fails closed. Repo-scoped like every phase-log evidence (follow-up: a session_id on the dispatch row).
- **Reviewer count is mode-aware (v2.113.0)**: a security-engineer dispatch (qa-tester too, until v2.148.4) whose brief says `write-mode` authored tests and does not count as a review — before this, a test-writing security-engineer cleared the STRONG-review gate on a high-risk diff with no review having happened (`session_state.is_write_mode_brief`; the Codex `dispatch-proof` fallback has no prompt and stays mode-blind).
- **qa-tester never counts at the commit gate (v2.148.4)**: it verifies what the user sees (E2E / UI); the per-diff floor is one read-only `universal-reviewer` pass, so a qa-tester-only dispatch no longer auto-passes a logic diff or silences the SOFT `0 reviewers` line. The round breaker still counts it as review-shaped activity. Prose templates (`*.md.tmpl`, `*.mdc.tmpl`) are prose for the docs exemption and the money-term scan alike.
- **Bypass**: not needed — evidence auto-passes. `ROLEPOD_GATES_PASSED=1` / `[gates: pass]` are legacy markers (same evidence check; never honored without it). The env-prefix form is deliberately not prescribed anywhere: permission layers read `ENV=1 git commit` as gate circumvention and block it before the hook runs.

### `block-subagent-commit.sh` — PreToolUse Bash (core)

Sub-agents cannot run `git commit` / `git push` / `gh pr merge` / `gh pr create` / `git reset --hard` / `git push --force`. Lead owns version-control state after the reviewer pass.

- **Trigger**: `agent_id` field populated (sub-agent call).
- **Effect**: `permissionDecision: deny` with agent_type in reason.
- **Self-guards**: Lead Bash (no `agent_id`) → silent.
- **Bypass**: none — hard rule. Real-world failure (backend-developer committed bypassing qa-tester floor) motivated this.
- **Cannot-wait rule (v2.147.0, Claude only)**: a sub-agent's Bash call with `run_in_background: true`, or a gate (`make test*`, a `tests/integration/` script, `rolepod-cross-family --kind …` without `--detach`, or `--collect`) with no `timeout`, is denied. A gate that outruns the 120 s default is backgrounded and no completion notice reaches a sub-agent — a task owner idled a whole loop budget waiting for one. The wide `make test*` match is deliberate: in most repos `make test` is the long gate, and the reason's fix (`timeout: 600000`, or an explicit `timeout: 120000` for a gate known to be short) costs one resend once. The runner's instant modes (`--rounds`, `--pool`, `--jobs`, …) never match. Both rules share one tokeniser: one python pass per call, heredoc bodies dropped, shell `-c` strings recursed. The gate rule reads segment heads only (a false positive costs one resend); the version-control rule tries every token so a wrapped commit (`timeout 300 git commit`, `xargs git commit`) is still caught, skipping only a pure-output head (`echo` / `printf`). A heredoc body stays in only when a shell owns it (`bash <<EOF`, `cat <<EOF | sh`); a `cat`/`tee`/redirect body is data. Wrapper flags that take a value (`sudo -u user`, `nice -n 10`, `timeout 5m`) are skipped before the head. Residual: a `git commit` example inside a quoted string that is not a heredoc still denies (write reports through a heredoc).
- **Write rule (bash-writes-are-edits, 2026-09-18)**: a file written through Bash (`cat > f <<EOF`, `sed -i`, `perl -pi`, `tee`, `cp`/`mv`/`install` destination, `truncate`, `dd of=`, `rm`/`unlink` — `session_state.bash_write_paths()`) was invisible to the edit ledger and to a sub-agent's write-scope class check, both of which key on the CLI's Edit/Write/MultiEdit tools only. Runs for the Lead too, not only sub-agents: every detected path gets an `edit-ledger.py append` row (same shape `gate-reminder.sh` writes for a real Edit); a sub-agent's path is additionally checked against its write-scope class via a synthesized `subagent-write-scope.sh` input (`tool_name: Bash`, `tool_input.file_path: <path>`) — a deny there is returned with `shell write: <path> — ` prepended to its reason, otherwise unchanged. Precedence: commit deny (rule 1) > wait deny (rule 2) > write deny — a command rules 1/2 already deny never runs, so nothing was written and no ledger row is added. Cost: a cheap regex pre-check (`>`, `tee`, `sed`, `perl`, `cp`, `mv`, `install`, `truncate`, `dd`, `rm`, `unlink`) runs first in the same python pass; only a plausible match imports `bash_write_paths` and shells out to `git rev-parse` — a plain `ls`/`git log`/`grep` never pays for it. Claude and Codex both register this hook on Bash (matcher `Bash`), so the ledger half of the rule fires on both; the write-scope class-deny half needs `hooks/subagent-write-scope.sh` to exist beside it, and the Codex plugin now bundles that script too (2026-09-18) — even though Codex has no Edit/Write/MultiEdit/NotebookEdit tools of its own to gate, `[ -f "$SCOPE" ]` is true and a sub-agent's shell write there gets the same class deny as Claude, reaching it only through this Bash write rule. Cursor, opencode and agy have no equivalent PreToolUse Bash hook today, so a Bash write there is doctrine-only ("edit tools only") with no mechanical backstop at all — a later port is one registration (see `docs/cli-support.md`). Residual: a peer PreToolUse hook on the same Bash event (`precommit-gate.sh`) or the user's own permission prompt can still refuse the call AFTER this script has already appended a ledger row for it — each hook decides independently and this script cannot see a sibling's verdict, so a denied write can leave a false ledger row (same class of residual `gate-reminder.sh`'s ledger append already has against `subagent-write-scope.sh` for a real Edit).

### `subagent-write-scope.sh` — PreToolUse Edit/Write/MultiEdit/NotebookEdit (core, v2.111.0 · classes v2.112.0 · workflow v2.113.0)

A sub-agent writes only what its role owns. Measured before the hook (30 days of subagent transcripts, every product repo): 16 of 31 `general-purpose` dispatches edited product code with no role doctrine, no tool cap and no cohesion contract; `qa-tester` wrote 99 non-test product files (payments, account deletion, tenant erasure) and `security-engineer` edited auth routes — both agent files already said "the respective agent fixes", and the review floor then read a diff its own role had written. `universal-reviewer`, whose file says REJECT a fix request, wrote 0 of 21: a flat refusal in text holds, a "write-mode" that includes "fix code" does not. The write itself is the line.

| Class | `agent_type` (namespace stripped) | May write |
|---|---|---|
| generic | `general-purpose`, `default`, `claude`, `workflow-subagent` (a bare Workflow `agent()` — live-verified 2026-09-09; give a writing stage `agentType: 'rolepod:<role>'` and resume) | nothing in the product tree |
| test-only | `qa-tester`, `security-engineer` | test paths (`tests/`, `__tests__/`, `__snapshots__/`, `fixtures/`, `e2e/`, RSpec `spec/`, `*.test.*`, `*.spec.*`, `*.cy.*`, `*.test-d.ts`, `*.snap` of those, `test_*.py`, `conftest.py`, `vitest`/`jest`/`playwright` config …) + markdown. Deliberately product: `specs/` (a contract dir in rolepod's own convention), Python `*_test.py` (no discovery guarantee), plain `mocks/` / `factories/` / `seeds/` / `testing/` helpers beside source — the bypass env is the escape. Accepted ambiguity: a bare `spec/` used for contracts in a non-Ruby repo passes as RSpec |
| read-only | `universal-reviewer`, `scout` | markdown only |

- **Trigger**: `agent_id` populated AND `agent_type` in a class above. Live-verified 2026-09-09: an Agent spawn with `subagent_type` omitted arrives as `general-purpose`.
- **Effect**: `permissionDecision: deny` (fact → Fix → Exception, per class); the sub-agent returns the finding and the Lead dispatches the owning role. A row `{"phase":"write-scope","class":…,"decision":"deny",…}` lands in `phase-log.jsonl`.
- **Self-guards**: the Lead, every owning role (`*-developer`, `*-engineer` other than security, designer, PM, architect …), an unknown `agent_type`, OS temp roots (prefix-anchored: `/tmp/`, `/private/tmp/`, `/var/folders/`, the Python tempdir — a repo-internal `tmp/` stays product) and scratch / evidence paths (substring: `scratchpad/`, `.rolepod/`, `.claude/agent-memory/`, `docs/rolepod/`) pass silently.
- **Bypass**: `ROLEPOD_ALLOW_OUT_OF_SCOPE_WRITE=1` (user-set; logged to `bypass.log`).
- **Not enforced**: an owning role drifting across domains (backend-developer in a billing route, billing-engineer in a layout) — measured but path→domain is a heuristic; the task brief's Files allowed / forbidden bounds it.
- **Ledger note (bash-writes-are-edits, 2026-09-18)**: this script is also invoked directly by `block-subagent-commit.sh`'s write rule, with a synthesized input (`tool_name: Bash`, `tool_input.file_path: <the detected path>`) standing in for a real Edit/Write call — the class rule above applies identically. The caller prepends `shell write: <path> — ` to a deny's reason; this script's own message text and 600-char budget are unchanged.

### `workflow-tier-nudge.sh` — PreToolUse Workflow|Agent (core)

Re-injects the tier-per-stage rule at the one moment it is needed — when a Workflow script or Agent call is about to dispatch. The rule lives in the `using-rolepod` router, which is not loaded while authoring a fleet; without this nudge an entire fan-out silently inherits the Lead's model.

- **Fleet-tier gate (v2.48.0, widened v2.50.0 — the deny branch)**: under a **strong-class** Lead (or a non-empty unknown family — assumed strong for cost) and no `// tier-reason: <why>` (legacy `fleet-inherit:`) comment in the script, a Workflow with `agent()` fan-out is denied when (1) it has zero `model:` / `agentType:` overrides (whole fleet at the Lead's price), (2) it names ≥2 stages (`phase()` calls / `meta.phases` titles / `label:` prefixes) but pins the ONE balanced tier on all of them — measured escape hatch: after v2.48.0 every fleet passed by pasting `sonnet` on every stage — or (3) on a **high-risk-shaped fleet** (the script names money / auth / security / migration surfaces) a judgment-shaped stage (verify / judge / review / refute / rank / score / adversarial / critic / synthesis) has no strong, role-pinned, or variable tier anywhere — a strong Lead running its R4 judge below itself — and, since v2.72.0, under a **balanced or cheap** Lead too: inherit or a balanced pin on that judge stage is the inverse trap, denied the same way (the tier follows the work, not the Lead). Routine fleets (i18n, UI copy, docs) judge at balanced by policy (R2) — v2.51.1 narrowed the rule after it pushed opus critics onto routine work. The deny names the stages and the per-stage fix (sweep → haiku, build/verify → sonnet or `agentType:'rolepod:<role>'`, judge → opus or inherit) — re-submit the same script and it passes. Each deny logs `reason: no-tier | single-tier | all-strong | no-strong-judge | strong-spread | bare-fanout` + `tiers` + `stages`. **v2.107.0 — per-call fan-out rules, no tier-reason hatch.** Observed 2026-09-08 (CourtBook `readiness-audit-live`, fable Lead): one `model:'opus'` on the Verify fan-out plus a `// tier-reason:` comment passed the whole script — Browse / Flows fan-outs stayed bare and inherited fable, Verify ran opus × N: 58 subagents = 44 opus + 13 fable + 0 sonnet, and every fleet that day carried a tier-reason. Now each fan-out `agent()` call (interpolated label, or inside `.map(` / `pipeline(` / `Array.from(` / a loop) is judged on its own opts: bare under a strong-class Lead → `bare-fanout`; pinned strong under ANY Lead → `strong-spread`. Neither yields to `// tier-reason:` (a reason can justify one strong slot, never the Lead price × N — pinning the fan-out is always possible) and neither takes the loop valve. Single bare calls stay allowed (a judge may inherit); the deny names the per-stage fix (read/browse → haiku or `rolepod:scout`, per-item verify → sonnet at high effort, one opus verdict). **v2.74.0 — one strong slot.** Observed (CourtBook `technician-payout-review`, sonnet Lead): `agentType:'rolepod:security-engineer'` on the Review stage plus 26 bare per-finding verify agents ran 30 × sonnet on a billing surface and the gate stayed silent — a role-pin counted as the strong stage, but strong roles render `inherit`, which under a low Lead IS the Lead. Now (a) a strong-role `agentType` counts as strong only under a strong Lead (no Workflow-path lift exists — reviewer opts usually come from a data array spread into `agent()`, so a text rewrite would not reach the call); (b) the low-Lead deny names the fix as ONE strong slot — `model:'opus'` on the single security-engineer / universal-reviewer call or on one final adjudicator that reads the verdicts, threaded (`model: r.model`) when the opts come from an array — never "opus on the judgment stage"; (c) the mirror trap is denied too (`strong-spread`): under a low Lead a strong literal on a fan-out call (interpolated `label`, or lexically inside `.map(` / `pipeline(` / `Array.from(` / a loop), on ≥2 stages, on a non-judgment stage, or on >2 calls. `strong-spread` never yields — dropping a pin is always possible, and a yielded paste is the very fleet the deny exists to stop. **v2.88.0 — an `agentType:` that pins nothing is not a tier.** `agentType:` counted as a tier choice whatever the agent was, so ONE `agentType:'general-purpose'` (a platform agent — it renders no `model:` and inherits the Lead) emptied the whole gate: no deny under a strong Lead, not even the low-Lead nudge (observed 2026-09-06: CourtBook `stripe-surcharge-research` ran its research fan-out at the Lead's tier in silence; `technician-payout-review` did it for 31 turns on a billing surface). Now only an agentType that RENDERS a pin counts — the cheap/balanced rolepod roles (`session_state.TIER_PINNED_AGENTS`, asserted against the tier overlays by `tests/static/hook-agent-matching.sh`) — plus a strong role under any Lead (v2.104.0 — it renders `opus`). `dispatch-auto-log.sh` applies the same rule to `tier_mix`, so the evidence stops reading a bare fleet as tiered. **Loop valve**: the same fleet name denied twice within 30 min → the third submission passes with a nudge (logged `action: yield`, surfaced by `make stats`) — a Lead that cannot satisfy the gate never spins; worst case is two extra turns (≈ $0.1-0.5 each) against the $100+ a strong-tier fleet leaks. Why a deny here and nowhere else in this hook: ultracode / workflow-heavy users run opus- or fable-class Leads and the platform default is inherit, so a model-less script bills the WHOLE fleet at the Lead's price — measured: 6 fleets in one day, 5,196 agent turns at opus/fable, ≈ $180 above the sonnet price for the opus share alone, with the soft nudge fired and ignored every time. Under a low-class Lead the fleet is already cheap → nudge only. Any per-stage `model:`, or an `agentType:` that actually pins a tier, → silent. Each deny is logged as `phase: "dispatch-gate"` in phase-log (a denied fleet never reaches PostToolUse) and counted by `make stats` per reason; `ROLEPOD_GATES_SOFT=1` degrades it to the nudge (logged to bypass.log). Under a low-class Lead the COST branch does not fire (the fleet is already cheap) — `no-strong-judge` (v2.72.0) and `strong-spread` (v2.74.0) do, and so does the nudge, which since v2.88.0 names `rolepod:scout` / `haiku` for sweep stages instead of calling an inherited sweep fine.
- **Effect**: Lead-aware since v2.47.0 — the hook reads the Lead's current model from `transcript_path` (last assistant turn) and classifies its FAMILY (haiku = cheap, sonnet = balanced, opus/fable/mythos = strong, else unknown). Workflow with `agent()` fan-out and zero `model:` overrides → fleet-inherit nudge whose wording depends on the Lead's class (strong Lead: "pin build stages to sonnet — the whole fleet runs at the Lead's cost"; low Lead: "build stages are fine at that tier; sweep/research/read/map stages are NOT — `agentType:'rolepod:scout'` or `model:'haiku'`, cheap beats the Lead even here; the strong pass comes from an Agent-tool reviewer dispatch before commit" — v2.88.0 stopped the old wording from blessing an inherited sweep). `effort:` alone is depth, not tier — still nudged (it used to silence the hook and log as "mixed"). `system-architect` under a low Lead → "pass model:'opus'".
- **Bare writer inside a Workflow (v2.128.2)**: an `agent()` call with no `agentType:` on a stage whose name says it writes (Implement / Build / Fix / Integrate / Migrate / Refactor / Patch / Scaffold / Write) is denied at submit, under any Lead — `subagent-write-scope` would block its edits anyway, but only at the first Write, minutes into the run (observed: the tier deny steered a Lead to `model:` pins, the role-less P1-1 agent worked 96 turns and was blocked on its first Write; one agent and 7 minutes wasted, the run failed). A `model:` pin is a tier, not a write permission. Never yields to the loop valve; read-only stages (Research / Verify / Review) stay bare-capable; the write-time hook remains the backstop for stages whose name does not say they write.
- **Named downgrade inside a Workflow (v2.118.0)**: a stage whose `agentType:` is a strong role but carries an explicit cheap/balanced `model:` literal is NOT the strong slot — the same rule `count_workflow_reviewers` applies at commit time. High-risk fleet (money/auth/security/migrations) → `deny` (`named-downgrade`: the stage, role and model, Fix = drop `model:` on that ONE call or `model:'opus'`); routine fleet → one `additionalContext` line; `// tier-reason:` or a strong / absent model → silent. Observed 2026-09-10: `{agentType:'rolepod:security-engineer', model:'sonnet'}` on a Review stage passed this gate silently and the commit gate refused it three hours later — read by the Lead as two gates contradicting each other.
- **Strong-role floor (the rewrite branch)**: `security-engineer` / `universal-reviewer` / `system-architect` (architect since v2.73.0 — in teammate mode it writes the team's spec + cohesion contract) render `model: opus` on Claude since v2.104.0 (see `build/merge-agent.py`; `inherit` from v2.47.0 to v2.103 — the pin now holds where no hook runs: first action of a session, Workflow `agentType:`, hooks off, another harness). Dispatched with no `model` under a **known-low** Lead, the hook still returns `permissionDecision: allow` + `updatedInput` with `model: opus` (a pre-v2.104 user-level agent file may say `inherit`), and a `systemMessage` naming the floor. A strong or unknown Lead is left alone — `opus` is the paid ceiling of the tier by owner decision, a fable-class Lead is never lifted (cost). An explicit low `model:` on a strong role is never rewritten: it is named as a downgrade and the commit gate does not count it as the strong pass. All hook Python runs `python3 -I` since v2.104.0: a file in the working directory named like a stdlib module (`json.py`, `nt.py`) no longer silently disables a hook (measured: a stray `/tmp/nt.py` muted every hook run from `/tmp` on one machine, floor included).
- **Self-guards**: any per-stage `model:`, an `agentType:` that pins a tier (cheap/balanced role, or a strong role — it renders `opus` since v2.104.0), or either key written as a variable → silent — a platform `agentType:` (`general-purpose` / `Explore`) pins nothing and no longer buys silence (v2.88.0); specialist writer agents → silent; no JSON / no input / no `session_state.py` → silent; no transcript yet (fresh session's first action) → nudge, never deny.
- **Bypass**: `ROLEPOD_NUDGE_OFF=1` (shared with `claim-verify-nudge.sh`).
- **Pair**: skill `using-rolepod` (tier-per-stage paragraph).

### `dispatch-auto-log.sh` — PostToolUse Workflow|Agent (core)

Auto-appends the dispatch intent line to `<git-root>/.rolepod/evidence/phase-log.jsonl` — automation over doctrine, because the manual "log EVERY dispatch" rule was forgotten by the model that wrote it.

- **Fleet cost (v2.108.0, `make stats`)**: the phase-log records the tiers a script *declared*; the model each fleet agent *actually ran on* lives only in the Claude subagent transcripts (`~/.claude/projects/<root with / as ->/<session>/subagents/{workflows/<wf>/,}agent-*.jsonl`). `make stats` now reads them (last 14 days, this repo's key only, `<synthetic>` placeholders skipped) and prints one line per fleet — agents / output tokens / cache-read tokens per model — plus totals and a warning when strong-class agents outnumber cheap/balanced ones (fan-outs ran at the Lead price). Tokens are summed per model per assistant line (an agent that switched model mid-run counts under both), a workflow agent's own sub-spawns stay in its workflow. Measured the day it was added (CourtBook, 14 days): 637 agents = opus 431 · sonnet 168 · haiku 24 · fable 14 — the phase-log had shown 0 of that.
- **Effect**: one JSONL line per dispatch — `phase: "dispatch"`, `provenance: "hook-auto"`, tool (Agent/Workflow), `agent_type` or workflow `name`, `model` (explicit value; `opus` for a model-less strong role since v2.104.0; else `inherit`), `override`, and since v2.47.0 `lead_model` + `lead_class` (family word only — rename-proof within a family, `unknown` otherwise), `model_overrides` / `effort_overrides` counted separately (a Workflow is `mixed` only on `model:`), the model literals + `agent_types` the script names and their `tier_mix` (v2.48.1 — so `make stats` can tell a real per-stage spread from one model pasted on every stage), and `floor: "applied"|"frontmatter"|"missed"` on a strong review role (applied = the hook wrote `opus` under a low Lead, frontmatter = the role's own `opus` pin ran, missed = an explicit low model) — read from the PostToolUse `tool_input` (which carries the tier-nudge lift), never inferred.
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

## Edit ledger — CLI-neutral edit evidence (v2.134.0)

The commit gate's "test edits / high-risk edits since the last commit" used to come from
the Claude transcript only (`hooks/lib/session_state.py`), so on Codex, Cursor, Antigravity
and opencode both counts read 0: the "high-risk edits without a test" HARD path never fired
and the test-edit auto-pass never cleared a block. Now every CLI's edit hook appends one
line per edited file to `<git root>/.rolepod/evidence/edits.jsonl`
(`{"t","ts","cli","path","kind":"test|risk|other","agent"}`) through the standalone
`hooks/edit-ledger.py`, and `precommit-gate.sh` / `gate-reminder.sh` take
max(transcript, ledger) per counter — never the sum. Classification is the transcript
scan's, byte-for-byte (test wins; risk = high-risk path AND code file; pinned by
`tests/static/edit-ledger.sh`). The ledger rotates at 512 KB (newest 2000 lines) and
fails open everywhere (no git root, bad stdin → silence).

| CLI | writer | reader |
|---|---|---|
| Claude | `gate-reminder.sh` on PreToolUse Edit/Write/MultiEdit/NotebookEdit (`append-stdin`) | shared gates, max with the transcript scan |
| Codex | the same `gate-reminder.sh` on `apply_patch` (every `*** Add/Update/Delete File:` in the patch, tagged `codex`) | shared gates (no transcript → the ledger is the count) |
| Cursor | `scripts/gate-reminder.sh` on postToolUse | `scripts/precommit-gate.sh` is now a translator around the shared gate (`scripts/shared/precommit-gate.sh`) — same tiering, window and auto-pass as Claude; a deny reaches the model as `agent_message` |
| Antigravity | `hooks/pre-tool.sh` on the edit tools (`write_to_file|replace|edit|edit_file|multi_replace_file_content`), silent | `hooks/pre-tool.sh` → shared gate on `run_command` |
| opencode | `plugins/rolepod.js` on `tool.execute.after` edit/write (`rolepod-shared/edit-ledger.py`; opencode 2: `ctx.tool.hook("execute.after")`, input key `path`) | the plugin's `git commit` deny counts the ledger since the last commit (was in-memory per session) |

Route record + reviewer evidence on every CLI (v2.135.0, slice B): `hooks/lib/route_check.py`
now reads the turn's assistant text from whichever transcript the Lead's CLI keeps —
Claude JSONL, Cursor `agent-transcripts`, Codex rollouts, Antigravity `transcript_full.jsonl` —
so the Stop hooks of Codex (`session-lifecycle.sh --unlock`), Cursor (`scripts/stop-unlock.sh`)
and Antigravity (`hooks/stop-unlock.sh`) all record the `phase:"route"` line; opencode keeps no
transcript file, so its plugin hands the turn's text to `route_check.py --record-text` at
`session.idle` on opencode 1.x and, on opencode 2, from the `context` hook's messages at the
start of the next turn (the prompt time is the once-per-turn guard). Reviewer dispatches land as
`dispatch-proof` lines from Cursor's `scripts/dispatch-log.sh` (preToolUse Task, `subagent_type`)
and opencode's `task` (opencode 2: `subagent`) tool, next to Codex's SubagentStop line — the shared gate counts them
without a transcript. Still transcript-only: claim-verify's prompt state (context size and
auto-resume shape) on non-Claude CLIs.

## Bypass envs — when to use

| Env | When |
|---|---|
| `ROLEPOD_GATES_SOFT=1` | Iterating on doctrine itself; want warnings instead of hard blocks for one session. Set **permanently** (e.g. in a project's `settings.local.json` `env`) it silences the commit gate and the fleet-tier gate — the only hard checkpoints left — for good; `make stats` shows every use |
| `ROLEPOD_GATES_PASSED=1` | Human-only, set at CLI launch. Legacy for commits: the precommit gate auto-passes on windowed evidence, and an env-prefixed `git commit` is never prescribed (permission layers read that shape as gate circumvention) |
| `ROLEPOD_ALLOW_OUT_OF_SCOPE_WRITE=1` | A reviewer or generic sub-agent must write outside its class for one dispatch (e.g. a qa-tester fixing a test helper that lives beside source). User-set; logged. |
| `ROLEPOD_ALLOW_SHARED_WORKTREE=1` | Intentional shared session (read-only review, paired exploration) |

Never set these globally — apply per-command only. Hard rules exist because real-world failures triggered them. **And they are the user's hand only:** a model that meets a gate conflicting with a standing instruction surfaces the conflict with options (e.g. Lead cold self-review recorded as a limitation) — it never sets a bypass env itself. Hook block messages, the always-on core, and review-code all state this; a self-set bypass in `bypass.log` is a finding, not a workaround.

**Bypass accountability.** Every used bypass is appended to `<git-root>/.rolepod/evidence/bypass.log` as one JSON line — `{"ts","hook","var","reason"}` — with the reason taken from `ROLEPOD_BYPASS_REASON` (defaults to `"unreasoned"`). `rolepod-selftest` is reserved: `rolepod doctor` and the integration suite tag their own bypass probes with it, and `rolepod-stats` counts those rows apart from human bypasses (legacy tag `doctor` reads the same). Logging never blocks and fails open. A silent bypass normalizes itself; a recorded one stays visible in review.

### Cross-family pool — `.rolepod/cross-family` (v2.76.0)

Cross-family is **opt-in and off by default**. Which CLIs may serve as the
reviewer / advisor is the user's choice, not PATH's: `<git-root>/.rolepod/cross-family`
(project) overrides `~/.rolepod/cross-family` (machine); one CLI per line in
preference order, `#` comments; **no file = off, `none` = off**:

```
# this machine has four CLIs; use three
[reviewer]
review = agy codex opencode stall=900   # the default order for every kind; stall= is codex's silence budget (default 600 s)
consult = agy codex                     # per-kind order: the debug loop wants the fast answer first

[implement]
cli = codex claude                      # which members may WRITE a ticket (--kind implement, v2.139.0)
```

(The older shape — bare lines plus `consult: agy codex` per-kind lines — still reads.)

Per-member time (v2.129.0): a member is killed when it goes SILENT — no new
stdout / stderr for `stall` seconds (`--stall` > `stall=` > 600) — not when
it is slow; the wall-clock cap is runaway insurance only (`--timeout` >
`timeout=` > kind default: review 7200 s when detached / 600 s foreground ·
consult 300 · critique 600). Measured 2026-09-15: codex reviews
run 15-29 min streaming the whole way (p90 28 min sat on the old 1800 s
cap), cursor stream-json and opencode stream, agy is silent ~150 s then
answers; a killed reviewer is money already spent, so the cut is for the
dead. The prompt carries a planning budget (≤30 min). `--detach` runs the chain as a job
under `.rolepod/evidence/external/jobs/<id>/` (`--collect <id>` waits,
`--jobs` lists); `precommit-gate` names a running job in its hold reason
instead of asking for a new run. A diff attachment that is a **partial
slice** — its files carry working-tree edits it does not contain (`git diff
--cached` while the same file has unstaged edits; a committed range after
the tree moved on) — is refused at dispatch (exit 7, `external-refused`
phase-log line, no member called): the reviewer reads the live tree, so the
verdict would be an artifact. Attach `git diff HEAD` or commit first;
`--partial-ok` only when the user asked for the staged part (v2.94.0).
One live review job per repo: a second `--kind review` is refused (exit 8)
until `--collect <id>` or `--kill <id>` (status 137, no anchor). Round 2+
uses `--since <job-id>`: every detached dispatch records a working-tree
snapshot (tree object; real index untouched), and `--since` attaches the
fix delta (snapshot → now, new files included) plus the previous report,
so the reviewer verifies the fixes and tags IN-FIX / NEW / REPEAT instead
of re-reading the cumulative diff (v2.98.0). **Breaker (v2.99.0, counted per
reviewer since v2.154.0):** `--rounds` prints the review rounds on the
current uncommitted tree, keyed by reviewer — `security-engineer` /
`universal-reviewer` / `code-reviewer` / `qa-tester` (from the phase-log
dispatch's role), `named` (a review-shaped dispatch name, no role match),
`external` (runner review jobs, counted per the gate-pass rule); a
reviewer's rounds are the clusters (dispatches closer than 5 min = one
round) that hold that reviewer, and the tree's `rounds` is the highest.
`--role <key>` asks one reviewer's `current` (a key never seen reads
current=1); with no `--role`, `current` is the highest over the reviewers
seen. Measured 2026-09-21: replaying every `phase-log.jsonl` (185
inter-commit windows with reviewer events) — the tree-level rule reads
round >= 4 in 7 windows and >= 5 in 4; counting per reviewer reads >= 4 in 2
and >= 5 in 2, exactly the two real churn loops the breaker was built for.
The window starts at the later of the last commit and the last prompt the
user typed (v2.128.0 — `claim-verify-nudge` stamps
`.rolepod/evidence/last-prompt`; auto-resume and compaction prompts never
stamp, so an overnight loop still accumulates), and a clean tree reads as 0
rounds. Measured 2026-09-14: five separate commissions in one day, on a
tree whose commits lived in another worktree, read as round 5 and blocked
the next task. A review dispatch at round 3 gets a notice; round 4 needs
`--ledger <file>` (that file must exist and carry a `## Class` heading, the
root cause was named — this flag's own check, unchanged). The AUTO-DETECTED
`ledger=` field (`--rounds`, the claim-verify reminder) is separate and
stricter (v2.154.0): only a `docs/rolepod/handoffs/*breaker*.md` newer than
the window start that ALSO carries a `## Rounds` heading counts — a review
brief merely named `*breaker*.md` is not the ledger. Round 5 is refused
(exit 9): split & stop, the terminal text names the user's next typed
prompt as the way out (no new session, no bypass).
**The gate's pass is not a round (v2.154.0):** while the window
holds no anchored external review (the phase-log line + raw file the commit
gate counts), an external review run is never refused and its job never
counts — `--rounds` prints `gatepass=1`; the re-review after it is a round
again. Uncounted jobs stay in the timeline — they still join and bridge
events inside the 5-min window, and a cluster is a round only when it holds a
counted event — so nothing reads a round stricter than before (a seeded
invariant test compares against the exact pre-change, gate-pass-aware
formula — not a naive every-job-counts stand-in). Measured 2026-09-21: four internal
reviewer dispatches put a high-risk tree at round 5, the commit gate demanded
the external pass, the runner refused it, and the refusal's Fix said
"commit" — a circle only the user's next prompt could leave. `workflow-tier-nudge.sh` applies the same policy to internal
reviewer dispatches (notice / deny / deny) and `claim-verify-nudge.sh`
reminds every prompt while a breaker ledger is open, so an auto-resume
prompt cannot reopen the loop. Measured need: 11+ rounds overnight on one
tree, no consult, no hand-back, while the breaker was doctrine only.
**Pre-existing findings (v2.164.0):** a pre-existing issue on a path the diff does not touch is one note line in the report and never drives the verdict.

Names: `codex` `claude` `agy` `cursor` `opencode` (the standalone Gemini
CLI is retired — a `gemini` line is skipped with a note). **Never asked unprompted (v2.142.0):** the
SessionStart loader (`project-context-loader.sh` on Claude + Codex, the
gemini/agy `session-start.sh`) sees no file and a second CLI installed →
ONE silent context line naming `rolepod-cross-family --setup`. When the user
asks to set it up, the Lead runs `--setup` (candidates + the two questions),
asks review order then implement (`same` / `none` / an order), and writes the
file with `--setup review="…" implement=…` — ALL the names they want (the Lead's own CLI
included: it is skipped at run time, so one file serves every Lead), or
`none` — then drops the marker so it never nags. Rolepod never enables it unasked. Only the Lead's own CLI is
excluded; the model family is recorded for information (`agy` = google;
`cursor` / `opencode` = their default model, else `unknown`) and never
filters a member. Consumers: `scripts/cross-family.sh`
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
on a user who did not opt in. **R4 floor (D1, 2026-09-19):** the doctrinal
floor is `security-engineer` + ONE general strong pass; the gate's mechanical
bar is unchanged — it opens on ONE strong-class dispatch that has FINISHED —
so money / auth paths clear on the anchored external pass alone like every
other high-risk path (the v2.78.0 BOTH hold is gone — the pool exists to move
strong-class tokens off the main plan); the internal strong joins only at
review-code's round-3 breaker, by doctrine, not by the gate.
External failed (logged) → internal alone clears. **Code only (v2.143.0):** the hold needs a logic-bearing diff — a comment / blank-only change on a risky path clears with the internal strong reviewer; a prose file (`.md` / `.mdx` / `.txt` / `.rst` / `.adoc`, or an extension-less README / LICENSE / CHANGELOG) is never a risk path (a `+pattern` in `.rolepod/risk-paths` cannot re-flag one — accepted), and a docs-only diff passes the gate silently at any size (docs are written, not reviewed — owner rule; the private-docs deny still runs first). Doctrine side: the external reviewer is an R4 instrument — R3 stays internal unless the user asks. Measured before: 210 dispatches
across nine repos, zero cross-family passes — the internal reviewer was one
Agent call away and counted the same.

### Private working docs — `docs/rolepod/` never commits (v2.80.0)

Everything rolepod writes under `docs/rolepod/` — specs, plans, cohesion
contracts, decision maps, hand-off briefs — is confidential working material
by default: it describes what you are building before it exists. The skills
add `docs/rolepod/` to `.gitignore` on the first save, and `precommit-gate.sh`
**denies** any commit whose staged paths start with `docs/rolepod/` (the
classic leak is `git add -A`). A repository that deliberately tracks these
files creates `<git-root>/.rolepod/docs-tracked` — an explicit, reviewable
choice — and the gate steps aside. ADRs under `docs/adr/` are project
records and are unaffected.

### Per-repo risk-path override — `.rolepod/risk-paths`

The high-risk path list (auth/billing/payments/…) is built-in but repo-tunable. Create `<git-root>/.rolepod/risk-paths` with one extended regex per line:

```
# add repo-specific high-risk paths
+(^|/)pii(/|\.|_|$)
(^|/)gdpr-export
# exclude a false positive (this repo's "token" is a lexer, not a credential)
-(^|/)compiler/token
# collisions seen in real repos: a disclosure policy, a design system named
# after a brand, an invoice UI template — prose and pixels, not money paths
-(^|/)SECURITY\.md$
-(^|/)design-systems/stripe(/|$)
-(^|/)design-templates/invoice(/|$)
```

Bare or `+`-prefixed lines ADD patterns; `-`-prefixed lines EXCLUDE paths the built-in list would match; `#` starts a comment. Read by `precommit-gate.sh`, `gate-reminder.sh`, `session_state.py`, and `plan-lint.sh --brief` (the brief's `## Tier` follows the same list the gate will apply at commit — it matches with awk, so keep patterns to POSIX ERE: a GNU-only `\b` / `\<` / `\S` tiers the brief differently, and the gate stays the floor); absent file = built-ins only; unreadable file fails open. The strongest seed: paths whose git history shows the highest bugfix-commit density — measure, don't guess.

### Test-tampering lint — `hooks/test-diff-lint.sh`

Warn-only helper invoked by `precommit-gate.sh` (not a registered event hook). It greps the staged diff for the machine-checkable half of the writer's test self-check (implement-plan `tdd-by-risk.md`): focus/skip markers added on the way to green, deleted test cases, snapshot files refreshed with no test-logic change, DB mocks added under integration/e2e paths. Findings ride into the gate's warn/deny message; the lint itself never blocks — over-firing a hard block trains users to bypass gates. Every finding is accompanied by the HUMAN-ONLY caveat: whether expected values were derived from the spec or captured from current output is a judgment no grep can make, so a green lint must never be read as "tests are good". Since v2.103.0 it also flags a literal calendar date added under a test path — a written date expires and comes back as a red that is not a regression (measured: 41 of 125 test files in one project carried literal dates and 4 files went red on HEAD within a month); the fix is one frozen now.

### Self-test — `make doctor`

`scripts/doctor.sh` proves the enforcement layer mechanically: syntax-checks every hook, fires the SessionStart loader, and drives the three deny paths (subagent commit, high-risk commit without tests, cross-session same-file edit) with synthetic fixtures — plus verifies bypass logging and prints the installed version + enforcement tier per CLI. Run it after any CLI upgrade: a vendor hook API change that silently kills a deny path is exactly what this catches.

### Env namespace — `ROLEPOD_*` vs `CLAUDE_CODE_*`

Rolepod uses the `ROLEPOD_*` prefix exclusively for its bypass envs. Framework-scoped, separate from Anthropic's `CLAUDE_CODE_*` namespace (which controls Claude Code's own runtime behavior).

| Prefix | Owner | Scope |
|---|---|---|
| `CLAUDE_CODE_*` | Anthropic / Claude Code | Core CLI behavior |
| `ROLEPOD_*` | Rolepod framework | Hook bypass + framework-level toggles |

If rolepod ever needs to override a Claude Code core behavior, use the `CLAUDE_CODE_*` env directly per Anthropic docs — don't shadow it with a `ROLEPOD_*` wrapper.

## Cost and contract — two advisory commands (v2.128.0)

- **`make bench-hooks`** — wall-time of every Claude hook on a synthetic transcript and a throwaway repo (`RUNS=5 SIZE_MB=8`; `--json` for rows), plus the sum per tool-call shape. Measured before it existed: an Edit paid 523 ms of hooks, a prompt 527 ms, and two scans grew with the transcript (596 / 732 ms per edit at 261 MB). Never a gate — the signal is the catastrophic class (a full-file scan per call, a backtracking regex), which shows as seconds; a median above 250 ms is flagged SLOW.
- **`make contract-check`** — the facts the hooks and tier pins depend on (hook events, `hookSpecificOutput` keys, tool names, model ids; Codex effort enum, `spawn_agent` params, `[agents]` keys) derived from the installed binaries and diffed against `tests/contract/<cli>.snapshot`. Exit 1 DRIFT, exit 2 CANNOT-OBSERVE (a gate that cannot look is never green); `make doctor` runs it. After reviewing a drift: `make contract-update`.

## Ticket helper — two calls per task (v2.155.0)

Measured 2026-09-21 on a ten-task day: the Lead made ~35 calls per task at an average context of 576k — about 20M tokens of orchestration per task against ~6M of build and ~5.5M of review; ~11 of those calls were product-code reads for the spot-check, ~9 were plan bookkeeping edits. `rolepod-ticket` (`scripts/ticket.sh`, on PATH after install, shipped in every plugin tree) turns the mechanics into two calls (spec lean-loop-2026-09-23 Task 2):

- **`start <plan> <N> [--base <branch>]`** — runs `plan-lint`, writes the owner brief, creates the worktree + branch the brief names, prints the dispatch line (brief + worktree paths), `agent: <name>`, and a **`ship:`** line naming the whole chain below with `<commit gate>` / `<subject>` / `<note>` left for the Lead to fill in. Idempotent.
- **The ship chain** — ONE Bash call the Lead runs once the owner returns, after filling the `ship:` line's three placeholders: `integrate <worktree> --brief <file> --gate '<cmd>'` fast-forwards to the base, stages everything except `docs/rolepod/`, runs the brief's **Proof** (the plan's optional `- **Proof:** <claim> :: \`<command>\`` line — the owner already ran the Command itself) then the gate, prints `ok` or the failing tail per step plus the diff stat and reviewer verdict lines, then `&&`-chains into `git -C <worktree> commit -m '<subject>'` → **`finish <worktree>`** (fast-forward merge, `worktree remove`, `prune`, `branch -d`, names the agent to close) → **`log <plan> <N> --sha "$(git rev-parse HEAD)" --note '<note>'`** (flips the task's checkboxes, appends one bullet under `## Changes during build`, names every task Task N just unblocked, plus a `fleet:` line when one is role-owned, plus a `review: <first logged task sha>^..HEAD — one combined review before release (implement-plan §6); lens diff: <path>` line once every role-owned task is done — the diff of that range, generated files left out, written to `.rolepod/evidence/review/<plan-slug>.diff` for the lenses, which have no shell). A red step stops the chain before the commit — nothing after it runs.

On the one CLI with a workflow tool, **`fleet <plan> [--base <branch>] [--max <N>] [--gate '<cmd>']`** runs `start` for every task whose Blocked-by tasks are all done and whose Owner is a role (not Lead), reads each brief's reviewers, and prints one `{scriptPath, args}` object for `scripts/ticket-fleet.js` — one launch builds and reviews every ready task, returning each one's owner status and reviewer verdicts. The fleet has no scripted verifier stage: the owner prompt tells the owner to run the brief's `## Command` after each edit and last before returning; the verifier is `rolepod-ticket integrate`, which runs the Proof once before the ship chain is printed. Integration and the commit still go through `integrate` / `finish` on the Lead's side; the fleet counts as ONE review-shaped launch for the round breaker, not one per reviewer stage. `ticket-fleet.js` ships next to `ticket.sh` in every plugin tree (also via `install.sh` to `~/.rolepod/bin`) — a marketplace-only Claude install has it too, and `fleet` still fails closed if a resolved path is somehow missing rather than print a scriptPath that does not exist. `start` and `fleet` hold a per-plan lock in the git dir for their run — two overlapping fleet runs used to both emit every ready task (34/40 overlapping runs, 2026-09-23); now the second refuses until the first ends, and a lock whose process is gone is taken over.

Three launch-safety rules added on top: `--gate '<cmd>'` runs once in the checkout `fleet` was called from, before any `start` — a non-zero exit prints its tail and refuses with `base gate red` and no worktree created at all. A ready task whose worktree already exists (an earlier `fleet`/`start` already launched it) is reported as "in flight" and skipped — left out of the JSON, never re-started, so re-running `fleet` on a plan whose earlier tasks already launched is safe. `--max <N>` keeps only the first N still-not-in-flight tasks in plan order and names the rest as held back, deciding before `start` is ever called so a held-back task never gets a worktree.

**Test levels** — the rule every brief prints, and the reason the loop is fast:

```
Test levels — each runs at ONE point:
1. Command — the tests covering this task; the owner runs it after each edit and last before returning.
2. Release — the whole-repo suite; runs ONCE per release, by the Lead.
```

Measured 2026-09-22: before the rule, one task's owner ran two full hook suites ~10 times (40 % of a 41-minute fleet chain); a fleet verifier stage then ran the Command again, and `integrate` a third time. A red `integrate` prints the failing tail and the one Fix: send it to the task owner in a new dispatch — the Lead never repairs it.

No new deny and no new stop: the helper only removes calls.

## Why hooks, not just doctrine

Doctrine (CLAUDE.md text) tells the model what to do. Hooks **enforce** it. Models drift, especially under flow-state success cues — soft reminders get ignored. Hard blocks via `permissionDecision: deny` are the only mechanism that survives drift.

Two real failures motivated dedicated hooks, both hard:
1. Sub-agent ran `git commit` after marking COMPLETED, bypassing qa-tester floor → `block-subagent-commit.sh`
2. Concurrent Claude sessions on same worktree stomped each other's edits → `session-lifecycle.sh --lock`

(A third — Lead spawned 2+ parallel agents without a cohesion contract, producing incompatible interfaces — motivated `cohesion-contract-check.sh`; the hook was a nudge from v2.163.0 and was removed v2.164.0. `write-plan`'s cohesion-contract step remains the doctrine side.)

## Why no "spec required" hook

Spec discipline is enforced via:
- `core/skills/write-spec/SKILL.md` — Iron Rule + approval gate + self-review
- `using-rolepod` router — Define phase exit evidence

Adding a `PreToolUse Bash` hook that checks for `docs/rolepod/specs/<feature>-YYYY-MM-DD.md` before Build-phase skills would duplicate `precommit-gate.sh`, block legitimate trivial builds, and force a layout schema on user repos. Decision: keep spec gating as doctrine.

## Root vs Codex adapter parity

Root `hooks/*.sh` is canonical. The Codex adapter mirrors the hooks whose events Codex supports (`SessionStart`, `UserPromptSubmit`, `PreToolUse apply_patch|Bash`, `PostToolUse Bash`, `Stop`, `SubagentStart`/`SubagentStop` — per the official hooks reference, verified 2026-08-05):

- **`scripts/cross-family.sh` (all CLIs, not a hook, v2.76.0)** — the cross-family runner the hooks and skills call; `render_evidence_scripts` copies it into every plugin tree's `scripts/` next to `stats.sh`, and the hooks resolve it as `../scripts/cross-family.sh` from their own directory (fallback `~/.rolepod/bin/`). One command = pool from config → first usable different-family CLI, read-only, its default model, clean room → raw output + phase-log line anchored. Behavioural test: `tests/integration/cases/cross-family-runner.sh` (stub CLIs, sandbox HOME).
- **8 shared scripts render-copied** from canonical `hooks/` into `plugins/rolepod-codex/hooks/` by `build/render.sh` (since v2.39.0 — the hand-maintained mirror tree is gone): `gate-reminder.sh`, `precommit-gate.sh`, `project-context-loader.sh`, `claim-verify-nudge.sh`, `block-subagent-commit.sh`, `session-lifecycle.sh`, `test-diff-lint.sh`, `fix-loop-breaker.sh`. Codex uses the same event names, stdin JSON, and `hookSpecificOutput`/`permissionDecision` protocol as Claude, so the scripts are shared verbatim (all smoke-tested against Codex-shaped payloads). Only `hooks.json`, `subagent-model-log.sh`, and `agent-sync.sh` live in the adapter dir. `hooks/lib/` (session_state.py, route_check.py) is render-copied as well since v2.128.1 — the shared scripts resolve it relative to themselves, and without it the Codex copies silently ran their no-lib fallbacks.
- **`agent-sync.sh` (Codex-only, SessionStart, v2.75.0)** — the Codex plugin manifest has no `agents` component, so `codex plugin marketplace upgrade` alone never refreshed the 15 role agents or the `~/.codex/AGENTS.md` block. The plugin now bundles both (`plugins/rolepod-codex/agents/rolepod-*.toml` + `agents/AGENTS.rolepod.md`, rendered by `build/render.sh`); on session start the hook compares the plugin version with `~/.codex/agents/.rolepod-agents-version` and, when they differ, copies changed `rolepod-*.toml` files in, prunes retired ones (prefix-scoped — user agents are never touched), and replaces ONLY the `<!-- rolepod:start -->` … `<!-- rolepod:end -->` block of `~/.codex/AGENTS.md` (content outside the block is preserved byte-exact; no block → appended; file missing → created block-only). Fail-open and silent unless something changed (then one `additionalContext` line). `ROLEPOD_AGENT_SYNC_OFF=1` disables it; `install.sh` writes the same stamp so a fresh install is not re-synced on first launch; honors `CODEX_HOME`. Proven by `tests/integration/cases/codex-agent-sync.sh` against a sandboxed HOME. **Trust gate (Codex policy, verified 2026-09-03 against the official hooks reference):** Codex records hook trust against the hook definition's hash and *skips* new or changed plugin hooks until the user reviews them with `/hooks` — so the first session after this hook lands (or after its definition changes) needs that one-time trust; `codex exec` has `--dangerously-bypass-hook-trust` for vetted automation only.

`always-on-loader`, `worktree-guard` stay Claude-only (`always-on-loader` is unnecessary on Codex/Gemini/Cursor — they load their always-on core natively from `AGENTS.md` / `GEMINI.md` / `rules/*.mdc`; `worktree-guard` extracts `file_path`, which `apply_patch` input does not carry).

Drift is structurally impossible: the shared scripts have exactly one source (`hooks/`), `make test-render-clean` git-diffs the committed render output, and `tests/static/lean-surface.sh` pins the adapter dir to its two Codex-specific files.

## Cursor adapter mapping

The Cursor adapter ships **5 core hooks** in `adapters/cursor/scripts/`, parallel to Codex but with Cursor's I/O contract (stdin JSON / stdout JSON / exit-code 2 to deny):

| Claude hook | Cursor mapping |
|---|---|
| `always-on-loader.sh` (SessionStart) | replaced by `rules/always-on-core.mdc` with `alwaysApply: true` — Cursor's native always-on mechanism |
| `project-context-loader.sh` (SessionStart) | `scripts/project-context-loader.sh` on `sessionStart` — emits `{"additional_context": "..."}` |
| `gate-reminder.sh` (PreToolUse:Edit\|Write\|MultiEdit) | `scripts/gate-reminder.sh` on `postToolUse` (matcher `Write\|Edit\|MultiEdit`): the soft reminders as `{"additional_context": "..."}` (high-risk path edited) plus the edit-ledger row. `additional_context` is not a `preToolUse` field and `agent_message` reaches the model only on deny (live-verified 2026-09-16); the v2.130.2 write-time deny was removed in v2.134.1 after a live run showed the model answering it by creating the file through the shell — advisory at write time, as on Claude; the commit gate is the stop |
| `precommit-gate.sh` (PreToolUse:Bash) | `scripts/precommit-gate.sh` on `beforeShellExecution` with matcher `git[[:space:]]+commit` — same tiering (silent / soft / hard), same `ROLEPOD_GATES_HARD` / `ROLEPOD_GATES_SOFT`; **no evidence auto-pass** (Cursor exposes no session transcript), so `[gates: pass]` in the commit message body stays the release valve there |
| `session-lifecycle.sh` (SessionStart/Stop lock) | `scripts/project-context-loader.sh` registers `cursor-<conversation_id>.lock` on `sessionStart`; `scripts/stop-unlock.sh` releases it on `stop` (v2.132.0) |
| `fix-loop-breaker.sh` (PostToolUse:Bash) | not portable — `afterShellExecution` carries command + output but no exit code, and no field reaches the model there |
| `push-ref-check.sh` (PreToolUse:Bash) | not portable — `beforeShellExecution` has no informational channel (only deny) |
| `block-subagent-commit.sh` (PreToolUse:Bash) | not ported — Cursor's subagent identity differs; deferred until `subagentStart` payload is exercised |
| `claim-verify-nudge.sh` (UserPromptSubmit) | not ported — Cursor's `beforeSubmitPrompt` is block-only (`{continue, user_message}`) and cannot inject pre-answer context; deferred until Cursor adds `additional_context` to that event ([feature request](https://forum.cursor.com/t/add-additional-context-to-beforesubmitprompt-hook-output/157231)) |

Cursor uses camelCase event names (`sessionStart`, `preToolUse`, `beforeShellExecution`) vs Claude's PascalCase. The `matcher` field accepts regex patterns matched against tool name (`preToolUse`) or full shell command (`beforeShellExecution`).

## Antigravity adapter mapping (v2.131.0)

Contract measured live on agy 1.2.3 (2026-09-16); the previous flat `hooks.json` never parsed on agy ≥1.1, so no rolepod hook had ever fired there. The plugin ships **4 core hook scripts** at `hooks/` plus the shared gate pair (`precommit-gate.sh`, `test-diff-lint.sh`) it delegates to:

| Claude hook | agy mapping |
|---|---|
| `session-lifecycle.sh --lock` + `project-context-loader.sh` | `hooks/session-start.sh` on `PreInvocation` — writes `.rolepod/parent-active` and the `agy-<conversationId>` session lock (same lock dir as every CLI); prints nothing |
| `dispatch-auto-log.sh` | `hooks/model-log.sh` on `PreInvocation` — one `dispatch-proof` phase-log line per model change (agy auto-selects models) |
| `precommit-gate.sh` (PreToolUse:Bash) | `hooks/pre-tool.sh` on `PreToolUse` matcher `run_command` — translates agy's `toolCall.args.CommandLine/Cwd` into the Claude-shape stdin, runs the shared `precommit-gate.sh` in the tool's cwd, and returns its deny as `{"decision": "deny", "reason": "..."}`; every other verdict is silence |
| `session-lifecycle.sh --unlock` | `hooks/stop-unlock.sh` on `Stop` |
| `always-on-loader.sh`, `terse-loader.sh`, `claim-verify-nudge.sh`, `gate-reminder.sh`, `worktree-guard.sh`, … | **not portable** — agy accepts no context field on any hook result (`systemMessage`, `additionalContext`, `hookSpecificOutput` are all "unknown field" errors), so nothing can be said to the model except a deny reason; the always-on core lives in `AGENTS.md` only |

Rules that follow from the contract: `hooks.json` must wrap the events in one name key (`{"rolepod": {...}}`); commands are relative to the `hooks.json` directory (`hooks/x.sh` — `${extensionPath}` is passed through literally); a PreToolUse hook prints exactly one deny object or nothing — `{}` denies, and any unknown field or non-zero exit blocks the tool. Without a Claude transcript the gate takes its non-Claude evidence path, so on agy the deny paths are the transcript-free ones (private docs staged, review-round breaker, `ROLEPOD_GATES_HARD=1`) until the evidence store is CLI-neutral. `agy -p` without `--add-dir` works in `~/.gemini/antigravity-cli/scratch`, never the repo — `cross-family` passes `--add-dir` since v2.131.0.

## opencode adapter mapping (v2.133.0)

Contract measured live on opencode 1.18.23 (2026-09-16): `tool.execute.before(input{tool, sessionID, callID}, output{args})` — throw = deny; `tool.execute.after(input{tool, sessionID, callID, args}, output{title, output, metadata})` — `output.output` is the string the model reads and is mutable, bash carries `metadata.exit`; `chat.message(input{sessionID, model}, output{message, parts})` fires per user prompt; events include `session.created` / `session.idle`. The plugin (`plugins/rolepod.js`) keeps its session lock, post-compact re-anchor and commit-gate deny, and since v2.133.0 runs the SHARED `hooks/fix-loop-breaker.sh` (shipped byte-identical in `plugins/rolepod-shared/`) behind an opencode→Claude translator: bash exit codes feed the loop breaker, and the nudge it emits is appended to the tool result. Not ported: claim-verify-nudge (needs the transcript-backed `lib/session_state.py`), push-ref-check (no informational channel before a tool), worktree-guard per-file lock (no per-file deny event). Headless note: `opencode run` blocks on tool permissions unless the project `opencode.json` allows them.

opencode 2 (v2.157.0, measured on 2.0.12, 2026-09-22): a v1 plugin no longer loads (`Plugin must export a default definition with an id and an effect or setup function`), so the same file also exports `default { id: "rolepod", setup(ctx) }` — opencode 2 reads the default export, 1.x reads the named one. The plugin runs inside the shared background service, one instance per project: `process.cwd()` is `$HOME` and `process.env` is the service's, so the directory comes from `ctx.location.directory` and an env flag reaches the plugin only through `ROLEPOD_GATES_SOFT=1 opencode service restart`; the service loads a plugin at boot and hot-reloads it on file change — `opencode reload` does not load plugins, so `install.sh` ends with `opencode service restart`. Mapping: `chat.message` → `ctx.session.hook("prompt")` (`e.prompt.text`, `e.sessionID`; the first prompt of a session registers the lock); `tool.execute.before` → `ctx.tool.hook("execute.before")` (`e.tool`, `e.input`; `bash` is now `shell` with `input.command`, `task` is `subagent`, `patch` is new, edit/write carry `input.path`); `tool.execute.after` → `ctx.tool.hook("execute.after")` (`e.status`, `e.result = { output, content, metadata }` — the cores measure the text of `content`, the nudge is pushed as a `{ type: "text", text }` part, shell exit at `metadata.exit`); the TUI toast → `ctx.session.hook("context")` pushing one system text part (sibling warning, post-compact re-anchor); `client.session.messages` at `session.idle` → the same `context` hook reads `e.messages` and records the previous turn's route line at the start of the next turn (one turn late, once per prompt); `session.compacted` → `session.compaction.ended`; `ctx.event.subscribe()` is one stream for every project, filtered by `data.location.directory` at `session.created` (a `parentID` marks a subagent child, skipped); `setup` returns the cleanup that aborts it. Orca terminals export `OPENCODE_CONFIG_DIR` to their own config dir — `unset OPENCODE_CONFIG_DIR` before verifying a global install from one.

## Installation

Hooks are shipped in the rolepod plugin tree (`~/.claude/plugins/rolepod/hooks/`) and declared in the plugin's `hooks/hooks.json` (the canonical plugin-root form). Re-running install is idempotent. Migration steps (pre-2.0 installs) strip any legacy hook entries from `~/.claude/settings.json`.

To verify installation:
```bash
claude plugin list
# Should show "rolepod" as enabled

claude plugin details rolepod@rolepod
# Component inventory should list a Hooks line covering UserPromptSubmit, SessionStart, PreToolUse, Stop
```

Expected: 14 core hook scripts / 16 registrations (UserPromptSubmit × 1, SessionStart × 4, PreToolUse × 8, PostToolUse × 2, Stop × 1 — `session-lifecycle.sh` registers twice, `--lock`/`--unlock`).
