# Hooks reference

Rolepod ships a family of **core bash hook scripts** in `hooks/`. Each CLI adapter declares the applicable ones in a plugin/extension `hooks/hooks.json` — Claude, Codex, Gemini, and Cursor all use the same `hooks/hooks.json` form (Cursor uses camelCase event names; the others use PascalCase). All hooks are **self-guarded** — silent no-op when a dependency is missing.

Lead does not invoke these manually. They fire automatically.

**Message shape (v2.92.0).** Every deny or nudge a hook emits is three parts and nothing else: the **fact** of this call (with its numbers — agent count, Lead model, stage names, diff size), the **fix** (the exact change that makes the same call pass), and the **exception** (the escape hatch, always user-set or stated in the artifact). The *why* — measured history, doctrine, the incidents that motivated a rule — lives in this file and in the hook's source comments, never in the message: the model cannot bypass a deny, so it never needed convincing, and every clause of persuasion was paid for on every fire. `tests/static/hook-message-lean.sh` holds the line — no `measured:` / `observed:` vocabulary in message text, no message literal over 600 chars.

## Hook categories — All core (no add-on hooks)

| Category | Hooks | Purpose |
|---|---|---|
| **Always-on** | `always-on-loader` | Inject the rolepod always-on judgment core as SessionStart context |
| **Enforcement** | `block-subagent-commit`, `subagent-write-scope`, `cohesion-contract-check`, `gate-reminder`, `precommit-gate` | Hard / soft blocks on discipline violations (high-risk path, parallel-without-contract, sub-agent commit, schema-bound new file) |
| **Context** | `project-context-loader` | Inject git state at SessionStart |
| **Session safety** | `session-lifecycle`, `worktree-guard` | `session-lifecycle`: SessionStart lock + Stop unlock. `worktree-guard`: hard-blocks an edit only when a live sibling owns that exact file — disjoint/solo edits flow free |
| **Answer-path** | `claim-verify-nudge` | Soft read-first nudge when a prompt asks for an analysis / diagnosis / "how does X work" / status — covers the claim/answer path that tool + lifecycle hooks miss. Since v2.49.0 also the **context-bloat check**: reads the last turn's context size from the transcript and, past 200k tokens, adds one note per 200k bucket per session — `additionalContext` for the Lead only (delegate reads to a scout; mention /compact or a fresh session to the user once, at a natural pause — the user-facing `systemMessage` was removed in v2.49.1 as friction). Measured need: a 12-day session ran every turn at 350-900k tokens; each turn re-reads all of it — one grep sweep = 31 turns × 558k ≈ $9. Claude/Codex `UserPromptSubmit`, Gemini `BeforeAgent`; soft, never blocks |

All core hooks register on every Claude install. rolepod-brain and GitNexus integrate via their own plugins/CLI, not rolepod hooks.

PR 6 dropped `verify-reminder.sh` (PostToolUse Edit/Write per-edit nag). The same discipline lives in:
- skill `check-work` — Iron Rule + evidence-required output contract
- `precommit-gate.sh` — hard-blocks commit on high-risk + zero tests; one advisory line when emoji lands in product code
- skill `using-rolepod` — Verify phase exit gate

A per-edit reminder hook duplicated all three without enforcement teeth — so it was removed instead of replicated.

## Event coverage

| Event | Matcher | Hooks |
|---|---|---|
| `SessionStart` | `startup\|resume` | `always-on-loader.sh`, `project-context-loader.sh`, `session-lifecycle.sh --lock` |
| `UserPromptSubmit` | (no matcher) | `claim-verify-nudge.sh` |
| `PreToolUse` | `Edit\|Write\|MultiEdit` | `worktree-guard.sh`, `gate-reminder.sh`, `subagent-write-scope.sh` |
| `PreToolUse` | `NotebookEdit` | `subagent-write-scope.sh` |
| `PreToolUse` | `Bash` | `precommit-gate.sh`, `block-subagent-commit.sh` |
| `PreToolUse` | `Agent` | `cohesion-contract-check.sh` |
| `PreToolUse` | `Workflow\|Agent` | `workflow-tier-nudge.sh` |
| `PostToolUse` | `Workflow\|Agent` | `dispatch-auto-log.sh` |
| `Stop` | (no matcher) | `session-lifecycle.sh --unlock` (+ route record, v2.105.0) |

## Per-hook reference

### `claim-verify-nudge.sh` — UserPromptSubmit (core)

**Route nudge (v2.98.0)** — a commission-shaped prompt (fix / add / change / build … + Thai equivalents; claim-shaped analysis prompts and Thai questions excluded) while the repo's newest `phase:"route"` line is older than the previous user prompt (transcript tail; no transcript → 30 min) → one `⟂ route:` line asking for the R0-R4 tier before the first edit. Checker: `hooks/lib/route_check.py`. Not a git repo → silent. Measured need: 199 requests / 0 router invocations in one project.

**Route record (v2.105.0)** — the same checker writes the route line itself. At Stop (`session-lifecycle.sh --unlock` → `lib/route_check.py --record`) and again on the next commission prompt as a fallback (an interrupted turn has no Stop), it reads the finished turn's assistant text from the transcript tail, finds the routing line the router prescribes — two shapes, both at line start: a `Route:` / `Tier:` field (`**Route: R2 — reason**`, `Route: R2 (one file + test) → <skill> · <reason>` — a gloss in parentheses after the tier is fine — `Tier: R3 (multi-file)` inside the block) or the pre-2.105 arrow form (`→ <skill> · R2 · …`) — and appends `{"ts","phase":"route","tier","skill","provenance":"hook-auto"}` once per turn — a turn that already has a route line, manual or auto, is left alone. Ignored on purpose: fenced code, `<skill>` / `<reason>` placeholders, `R0-R4` / `R3/R4` / `R3 (multi-file) | R4 (high-risk)` ranges — a gloss between the two codes is tolerated — (quoted doctrine, not a decision), `R3-B`-style labels, and anything mid-line. Why no bare `R2 (…)` shape and nothing mid-line — measured on 164,410 assistant lines across every local session: real routes are the field form (14, all `**Route: R2 — …**`), the `Routing:` block appeared 0 times, the arrow one-liner 0, the 4 mid-line `· R2 ·` hits were Cloudflare R2 table rows, and the 34 bare line-start `R2` / `R3-B` lines were phase labels and review-finding numbers. A user prompt with no timestamp is still the turn boundary (the dedupe then keys on the routing message's own timestamp). Known residual (constructed, 0 in the corpus; qa-tester round 3): a single-backtick inline quote `` `Tier: R3` `` or a blockquote `> Tier: R3` at line start still records — the markdown prefix is allowed on purpose because the real form is `**Route: R2 — …**`; not worth a fourth regex round. Measured 2026-09-08: the manual append the router asked for since v2.98.0 was written 0 times across every product repo on this machine (7 lines in rolepod itself), so the nudge fired on every commission and `make stats` had no tier distribution; the same day a 1-file CSS change under ultracode ran a design panel, a 14-agent review and the full e2e suite twice with its R2 stated only in chat.

**Auto-resume (v2.100.0)** — the harness prompt after a usage-limit pause ("Please continue from where you left off") gets one line: it is a resume, not a user decision — a turn that ended at a question / breaker / decision brief is restated, never continued into new scope or a new review round; the route nudge skips it.

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

Schema-bound + high-risk edit guard. Silent on normal code edits (PR 5 slim — the generic Q1-Q4 reminder lives in the always-on core / AGENTS.md / the using-rolepod skill, read once per session, not per edit).

Fires output ONLY when:
1. **Schema-bound NEW file** (plugin.json, marketplace.json, hooks.json, extension manifests) → soft warn: WebFetch spec FIRST.
2. **High-risk path** (auth / authentication / authorization / billing / migration / secret / crypto / token / oauth / jwt / sso / saml / webhook / stripe / paypal / charge / invoice — illustrative; canonical regex in the script, parity-pinned by lean-surface) → soft warn + auto-Careful banner with reviewer list (qa-tester + Codex/Gemini when binaries present).
3. **High-risk path + evidence gap** → the banner is prefixed with what the commit gate WILL require (`⛔ COMMIT WILL BLOCK — …`): 0 test edits since the last commit → write the failing test first; high-risk edits with 0 strong reviewers since the last commit → dispatch `rolepod:universal-reviewer` / `rolepod:security-engineer` before committing. **Warn-only, never a deny (v2.47.0)** — edit-time HARD blocks were the measured reason a user set `ROLEPOD_GATES_SOFT` for good (CourtBook: 33 high-risk edits in one day → 116 unreasoned bypasses), which then silenced the commit gate too. One hard checkpoint, at commit; this hook informs. Evidence window = since the last commit, Lead + subagent transcripts (same reader as the commit gate).

4. **Review in flight (v2.93.0)** — a detached cross-family job is still running (live pid under `.rolepod/evidence/external/jobs/`) and the edited file is in its attached diff (`+++ b/` paths from the job's `args`; attachments gone → the current `git diff HEAD` file list) → one advisory line (`⏸ REVIEW IN FLIGHT …`): the job reads the tree live, an early edit turns its verdict into an artifact and re-runs it. Never a deny; doctrine side = review-code §1 (the round ends when the last member returns; §6 starts on the merged list).

- **Self-guards**: docs / lockfiles / non-high-risk code → silent.
- **Bypass**: `ROLEPOD_GATES_SOFT=1` silences the would-block wording (banner stays) and the in-flight line.

### `worktree-guard.sh` — PreToolUse Edit/Write/MultiEdit/NotebookEdit (core)

- **Self-do nudge (v2.116.0)**: on an edit to a product-code file by the Lead (no `agent_id`), `lib/session_state.py selfdo-state` scans the transcript once — the newest routing line the Lead wrote (`Route: R3 …` / `Tier:` / arrow form, the shapes `route_check.find_route` accepts), then every Edit-tool call on product code (a non-test code file, or an infra file the Owner map assigns to devops-sre — CI workflow, Dockerfile / compose, vercel / wrangler / fly / railway config, `deploy/` `infra/` `terraform/`, release scripts; v2.117.0) and every writer-role dispatch (`WRITER_ROLE_AGENTS`: the ten owner roles of the plan-template domain map; Agent/Task `subagent_type` or Workflow `agentType`) at or after it. Route R3/R4 + ≥ 6 Lead product edits + 0 writer dispatch → one `additionalContext` line (fact → Fix: task brief to the Owner the map names → Exception: the user said self-do, or what remains is R1/R2-sized), ONCE per route (marker `<session_id>.selfdo` holds the route timestamp). Never on R1/R2, a subagent's edit, a test / doc / config target, or without a routing line; `ROLEPOD_NUDGE_OFF=1` silences. Guard: `tests/static/selfdo-nudge.sh`.
- **Reuse-ladder nudge (v2.109.0)**: the same per-session touched-files registry tells whether this file was edited before, so the simplicity ladder is injected as `additionalContext` at the moment scope creep happens and only there — the FIRST touch of a code file in the session (`✂ first touch of <file>: reuse before new logic (codebase → stdlib → platform → installed dep → one line before a helper)` — only the ladder; the scope rules stay where they already reach every CLI, the always-on core and S1-S5), a `Write` that creates a file (`✂ new file <file>: does it need to exist — extend an existing module first?` + the ladder), and every edit of a dependency manifest (`package.json`, `requirements*.txt`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `Gemfile`, `composer.json`, `pubspec.yaml`, gradle / pom, `Podfile`, `mix.exs` → a new dependency is the last rung, justify it). Docs / config / assets / build dirs stay silent; a second edit of the same file is silent; `ROLEPOD_NUDGE_OFF=1` silences it. ~45 tokens per fire, so an R3 task touching ten files pays ~450 tokens — the per-edit Q1-Q4 reminder this replaces was cut because it fired on every edit. Why here and not gate-reminder: the registry that knows "first touch" lives in this hook, and it runs first.

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

- **Effect** (evidence split by risk since v2.46.0): HIGH-RISK diff (path regex OR money-movement terms in staged added lines of non-test, non-prose files — `.md/.mdx/.txt/.rst/.adoc` never count as money logic, and a `-` line in `.rolepod/risk-paths` excludes a path from the content check exactly as from the path regex) → auto-pass ONLY on ≥1 strong-class adversarial reviewer dispatch (security-engineer / universal-reviewer, and NOT explicitly dispatched at a cheap/balanced model — a model-less dispatch counts because the role renders `model: opus` (v2.104.0) and `workflow-tier-nudge.sh` also lifts it on a low Lead); other HARD blocks → ≥1 test edit or ≥1 reviewer dispatch. Every auto-pass logs to `~/.rolepod/gate-bypass.log` (read by `make stats`) + additionalContext note; insufficient evidence → `permissionDecision: deny`.
- **Evidence window (v2.47.0)**: counted **since the last commit** (`git log -1 --format=%ct` — git's clock, unaffected by denied attempts, hook-less commits, or a 12-day session; no commit yet → whole session) across the Lead transcript **plus the session's subagent transcripts** (`<session>/subagents/**/agent-*.jsonl` — Agent tool and Workflow fleets, mtime inside the window, 60 newest). Measured need: a CourtBook session where session-cumulative evidence from day 1 (`tests=303 strong=2`) would have cleared every commit on day 12, while the tests the Workflow agents actually wrote (79–566 edits/day) were invisible to the Lead-only reader.
- **Review in flight (v2.93.0)**: a tree-rewriting git command (`stash` except `list`/`show`, `reset --hard|--merge|--keep`, `checkout`, `switch`, `restore`, `rebase`, `merge`, `cherry-pick`, `clean`, `pull`) while a detached cross-family job is live → one advisory `additionalContext` line naming the job and `--collect`; never a deny. The running-job walk is `xfam_running_job()`, shared with the commit hold.
- **SOFT line (v2.95.0)**: carries `reviewers since last commit: N`; a logic diff with 0 asks for a qa-tester read of the diff (review-code §1 R2 floor — the author never reviews own logic); an R1-shaped diff (1 file, ≤5 lines) gets the count only, since a user-facing string edit is R1 in the router (v2.96.0). Advisory.
- **Emoji in the product (v2.110.0)**: an emoji in an ADDED line of a staged non-prose, non-test file (`.md/.mdx/.txt/.rst/.adoc` and test-named / `tests|spec|fixtures` paths are never checked; comment lines are skipped) adds one advisory line — `emoji in product code: path:line <char>` — to whatever message the gate ends with (auto-pass note, HARD reason, SOFT warn, or the otherwise-silent R1 early exit). Never a deny on its own. Detection is the Unicode Emoji_Presentation set — every char in U+1F000–U+1FAFF, the BMP chars that default to colour emoji (✅ ❌ ⚡ ⛔ ⭐ …), and any char forced to emoji by U+FE0F (⚠️ ✔️); plain text marks (✓ ✗ ⚠ → ·) never match. Docs, code comments and commit messages may carry emoji; the shipped surface may not. A product that wants them (emoji-as-icon by choice) creates `<git-root>/.rolepod/allow-emoji` once — explicit, reviewable, user-set — and the line goes silent.
- **Self-guards**: non-commit Bash → silent; non-high-risk session → silent. Test-**named** staged files (`*.test.*` / `*.spec.*`, `test_*.py`, `*_test.go`, `*_spec.rb`, `*Test.java`) do not trigger the path regex (v2.85.2) — a test-only commit under `tests/auth/` is the QA-automation deliverable, and the same file is already exempt at edit time; a bare directory name (`tests/`, `spec/`, `e2e/`) is NOT an exemption, so `api/specs/auth.yaml` and `tests/fixtures/seed_auth_users.py` still block, and a mixed diff blocks on its production path. The money content-check also excludes these paths, so money logic living inside a test-named file is an accepted blind spot.
- **Reviewer count is mode-aware (v2.113.0)**: a qa-tester / security-engineer dispatch whose brief says `write-mode` authored tests and does not count as a review — before this, a test-writing security-engineer cleared the STRONG-review gate on a high-risk diff with no review having happened (`session_state.is_write_mode_brief`; the Codex `dispatch-proof` fallback has no prompt and stays mode-blind).
- **Bypass**: not needed — evidence auto-passes. `ROLEPOD_GATES_PASSED=1` / `[gates: pass]` are legacy markers (same evidence check; never honored without it). The env-prefix form is deliberately not prescribed anywhere: permission layers read `ENV=1 git commit` as gate circumvention and block it before the hook runs.

### `block-subagent-commit.sh` — PreToolUse Bash (core)

Sub-agents cannot run `git commit` / `git push` / `gh pr merge` / `gh pr create` / `git reset --hard` / `git push --force`. Lead owns version-control state after qa-tester + universal-reviewer pass.

- **Trigger**: `agent_id` field populated (sub-agent call).
- **Effect**: `permissionDecision: deny` with agent_type in reason.
- **Self-guards**: Lead Bash (no `agent_id`) → silent.
- **Bypass**: none — hard rule. Real-world failure (backend-developer committed bypassing qa-tester floor) motivated this.

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

### `cohesion-contract-check.sh` — PreToolUse Agent (core)

When Lead is about to spawn the 2nd+ engineering agent within 10 events, requires a contract file (`contract.md` / `SPEC.md` / `cohesion.md` / `specs/*.md`) to exist in the session.

- **Effect**: `permissionDecision: deny` if 2+ agents spawned without contract.
- **Self-guards**: 1st agent → silent; contract present → silent.
- **Bypass**: `ROLEPOD_NO_CONTRACT=1` (single-domain Agent spawn legit).
- **Pair**: skill `write-plan` (cohesion-contract step).

### `workflow-tier-nudge.sh` — PreToolUse Workflow|Agent (core)

Re-injects the tier-per-stage rule at the one moment it is needed — when a Workflow script or Agent call is about to dispatch. The rule lives in the `using-rolepod` router, which is not loaded while authoring a fleet; without this nudge an entire fan-out silently inherits the Lead's model.

- **Fleet-tier gate (v2.48.0, widened v2.50.0 — the deny branch)**: under a **strong-class** Lead (or a non-empty unknown family — assumed strong for cost) and no `// tier-reason: <why>` (legacy `fleet-inherit:`) comment in the script, a Workflow with `agent()` fan-out is denied when (1) it has zero `model:` / `agentType:` overrides (whole fleet at the Lead's price), (2) it names ≥2 stages (`phase()` calls / `meta.phases` titles / `label:` prefixes) but pins the ONE balanced tier on all of them — measured escape hatch: after v2.48.0 every fleet passed by pasting `sonnet` on every stage — or (3) on a **high-risk-shaped fleet** (the script names money / auth / security / migration surfaces) a judgment-shaped stage (verify / judge / review / refute / rank / score / adversarial / critic / synthesis) has no strong, role-pinned, or variable tier anywhere — a strong Lead running its R4 judge below itself — and, since v2.72.0, under a **balanced or cheap** Lead too: inherit or a balanced pin on that judge stage is the inverse trap, denied the same way (the tier follows the work, not the Lead). Routine fleets (i18n, UI copy, docs) judge at balanced by policy (R2) — v2.51.1 narrowed the rule after it pushed opus critics onto routine work. The deny names the stages and the per-stage fix (sweep → haiku, build/verify → sonnet or `agentType:'rolepod:<role>'`, judge → opus or inherit) — re-submit the same script and it passes. Each deny logs `reason: no-tier | single-tier | all-strong | no-strong-judge | strong-spread | bare-fanout` + `tiers` + `stages`. **v2.107.0 — per-call fan-out rules, no tier-reason hatch.** Observed 2026-09-08 (CourtBook `readiness-audit-live`, fable Lead): one `model:'opus'` on the Verify fan-out plus a `// tier-reason:` comment passed the whole script — Browse / Flows fan-outs stayed bare and inherited fable, Verify ran opus × N: 58 subagents = 44 opus + 13 fable + 0 sonnet, and every fleet that day carried a tier-reason. Now each fan-out `agent()` call (interpolated label, or inside `.map(` / `pipeline(` / `Array.from(` / a loop) is judged on its own opts: bare under a strong-class Lead → `bare-fanout`; pinned strong under ANY Lead → `strong-spread`. Neither yields to `// tier-reason:` (a reason can justify one strong slot, never the Lead price × N — pinning the fan-out is always possible) and neither takes the loop valve. Single bare calls stay allowed (a judge may inherit); the deny names the per-stage fix (read/browse → haiku or `rolepod:scout`, per-item verify → sonnet at high effort, one opus verdict). **v2.74.0 — one strong slot.** Observed (CourtBook `technician-payout-review`, sonnet Lead): `agentType:'rolepod:security-engineer'` on the Review stage plus 26 bare per-finding verify agents ran 30 × sonnet on a billing surface and the gate stayed silent — a role-pin counted as the strong stage, but strong roles render `inherit`, which under a low Lead IS the Lead. Now (a) a strong-role `agentType` counts as strong only under a strong Lead (no Workflow-path lift exists — reviewer opts usually come from a data array spread into `agent()`, so a text rewrite would not reach the call); (b) the low-Lead deny names the fix as ONE strong slot — `model:'opus'` on the single security-engineer / universal-reviewer call or on one final adjudicator that reads the verdicts, threaded (`model: r.model`) when the opts come from an array — never "opus on the judgment stage"; (c) the mirror trap is denied too (`strong-spread`): under a low Lead a strong literal on a fan-out call (interpolated `label`, or lexically inside `.map(` / `pipeline(` / `Array.from(` / a loop), on ≥2 stages, on a non-judgment stage, or on >2 calls. `strong-spread` never yields — dropping a pin is always possible, and a yielded paste is the very fleet the deny exists to stop. **v2.88.0 — an `agentType:` that pins nothing is not a tier.** `agentType:` counted as a tier choice whatever the agent was, so ONE `agentType:'general-purpose'` (a platform agent — it renders no `model:` and inherits the Lead) emptied the whole gate: no deny under a strong Lead, not even the low-Lead nudge (observed 2026-09-06: CourtBook `stripe-surcharge-research` ran its research fan-out at the Lead's tier in silence; `technician-payout-review` did it for 31 turns on a billing surface). Now only an agentType that RENDERS a pin counts — the cheap/balanced rolepod roles (`session_state.TIER_PINNED_AGENTS`, asserted against the tier overlays by `tests/static/hook-agent-matching.sh`) — plus a strong role under any Lead (v2.104.0 — it renders `opus`). `dispatch-auto-log.sh` applies the same rule to `tier_mix`, so the evidence stops reading a bare fleet as tiered. **Loop valve**: the same fleet name denied twice within 30 min → the third submission passes with a nudge (logged `action: yield`, surfaced by `make stats`) — a Lead that cannot satisfy the gate never spins; worst case is two extra turns (≈ $0.1-0.5 each) against the $100+ a strong-tier fleet leaks. Why a deny here and nowhere else in this hook: ultracode / workflow-heavy users run opus- or fable-class Leads and the platform default is inherit, so a model-less script bills the WHOLE fleet at the Lead's price — measured: 6 fleets in one day, 5,196 agent turns at opus/fable, ≈ $180 above the sonnet price for the opus share alone, with the soft nudge fired and ignored every time. Under a low-class Lead the fleet is already cheap → nudge only. Any per-stage `model:`, or an `agentType:` that actually pins a tier, → silent. Each deny is logged as `phase: "dispatch-gate"` in phase-log (a denied fleet never reaches PostToolUse) and counted by `make stats` per reason; `ROLEPOD_GATES_SOFT=1` degrades it to the nudge (logged to bypass.log). Under a low-class Lead the COST branch does not fire (the fleet is already cheap) — `no-strong-judge` (v2.72.0) and `strong-spread` (v2.74.0) do, and so does the nudge, which since v2.88.0 names `rolepod:scout` / `haiku` for sweep stages instead of calling an inherited sweep fine.
- **Effect**: Lead-aware since v2.47.0 — the hook reads the Lead's current model from `transcript_path` (last assistant turn) and classifies its FAMILY (haiku = cheap, sonnet = balanced, opus/fable/mythos = strong, else unknown). Workflow with `agent()` fan-out and zero `model:` overrides → fleet-inherit nudge whose wording depends on the Lead's class (strong Lead: "pin build stages to sonnet — the whole fleet runs at the Lead's cost"; low Lead: "build stages are fine at that tier; sweep/research/read/map stages are NOT — `agentType:'rolepod:scout'` or `model:'haiku'`, cheap beats the Lead even here; the strong pass comes from an Agent-tool reviewer dispatch before commit" — v2.88.0 stopped the old wording from blessing an inherited sweep). `effort:` alone is depth, not tier — still nudged (it used to silence the hook and log as "mixed"). Platform sweep Agent (`Explore` / `general-purpose`) with no `model` → cheap-class reminder (`rolepod:scout` is frontmatter-pinned cheap → silent); `system-architect` under a low Lead → "pass model:'opus'".
- **Strong-role floor (the rewrite branch)**: `security-engineer` / `universal-reviewer` / `system-architect` (architect since v2.73.0 — in teammate mode it writes the team's spec + cohesion contract) render `model: opus` on Claude since v2.104.0 (see `build/merge-agent.py`; `inherit` from v2.47.0 to v2.103 — the pin now holds where no hook runs: first action of a session, Workflow `agentType:`, hooks off, another harness). Dispatched with no `model` under a **known-low** Lead, the hook still returns `permissionDecision: allow` + `updatedInput` with `model: opus` (a pre-v2.104 user-level agent file may say `inherit`), and a `systemMessage` naming the floor. A strong or unknown Lead is left alone — `opus` is the paid ceiling of the tier by owner decision, a fable-class Lead is never lifted (cost). An explicit low `model:` on a strong role is never rewritten: it is named as a downgrade and the commit gate does not count it as the strong pass. All hook Python runs `python3 -I` since v2.104.0: a file in the working directory named like a stdlib module (`json.py`, `nt.py`) no longer silently disables a hook (measured: a stray `/tmp/nt.py` muted every hook run from `/tmp` on one machine, floor included).
- **Coordinator-loop check (v2.51.0)**: on an Agent dispatch that would be the Lead's **3rd sequential round-trip in one turn** (`session_state.py dispatch-rounds` — assistant messages carrying an Agent/Task tool_use since the last user prompt; parallel dispatches inside one message count once) → `additionalContext`, once per turn: every dispatch → wait → dispatch re-reads the whole context (size quoted) at the Lead's price; dependent multi-step fan-out belongs in a Workflow script whose stages chain outside the Lead. Borrowed from CCW's "Beat Model" (coordinator wakes only on callbacks) — the same cost driver measured here (Lead re-reads ≈ 90 % of spend). Merges with a tier note when both apply.
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

## Bypass envs — when to use

| Env | When |
|---|---|
| `ROLEPOD_GATES_SOFT=1` | Iterating on doctrine itself; want warnings instead of hard blocks for one session. Set **permanently** (e.g. in a project's `settings.local.json` `env`) it silences the commit gate and the fleet-tier gate — the only hard checkpoints left — for good; `make stats` shows every use |
| `ROLEPOD_GATES_PASSED=1` | Human-only, set at CLI launch. Legacy for commits: the precommit gate auto-passes on windowed evidence, and an env-prefixed `git commit` is never prescribed (permission layers read that shape as gate circumvention) |
| `ROLEPOD_NO_CONTRACT=1` | Single-domain Agent spawn that doesn't need cohesion contract (e.g. read-only research agent) |
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
agy
codex timeout=1800        # slow-but-deep member gets 30 min (per-CLI option)
opencode
consult: agy codex        # per-kind order: the debug loop wants the fast answer first
```

Per-member time: `--timeout` > `timeout=` > kind default (review 1800 s
when detached / 600 s foreground · consult 300 · advise 900 · critique
600); the prompt carries the budget. `--detach` runs the chain as a job
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
of re-reading the cumulative diff (v2.98.0). **Breaker (v2.99.0):** `--rounds`
prints the review rounds on the current uncommitted tree (reviewer dispatches
closer than 5 min = one round; internal roles from the phase-log, external
jobs from their start times) plus the breaker ledger state. A review
dispatch at round 3 gets a notice; round 4 needs `--ledger <file>` (a
`docs/rolepod/handoffs/*breaker*.md` with a `## Class` heading — the root
cause was named); round 5 is refused (exit 9): split & stop, the user
decides. `workflow-tier-nudge.sh` applies the same policy to internal
reviewer dispatches (notice / deny / deny) and `claim-verify-nudge.sh`
reminds every prompt while a breaker ledger is open, so an auto-resume
prompt cannot reopen the loop. Measured need: 11+ rounds overnight on one
tree, no consult, no hand-back, while the breaker was doctrine only.
**Provenance (v2.100.0):** every external finding carries INTRODUCED /
EXPOSED / ADJACENT (the review-report template and review-code §4/§6 say
the same for internal reviewers); ADJACENT findings never drive a
verdict and the author parks them in Follow-ups — one change stops growing
into 40 files. A diff attachment past ~15 files / ~800 changed lines gets
a capacity notice: split by concern before the pass.

Names: `codex` `claude` `agy` `cursor` `opencode` (the standalone Gemini
CLI is retired — a `gemini` line is skipped with a note). **Ask once:** the
SessionStart loader (`project-context-loader.sh` on Claude + Codex, the
gemini/agy `session-start.sh`) sees no file, no `~/.rolepod/cross-family.asked`
marker and at least one other CLI installed → tells the Lead to ask
the user this session (candidates from `rolepod-cross-family --candidates`)
and record the answer — ALL the names they want (the Lead's own CLI
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
on a user who did not opt in. **Money / auth paths need BOTH (v2.78.0):**
billing · payments · credits · auth · crypto · secrets · data deletion (and
the money-term content hit) require the external anchor AND an internal
strong reviewer dispatch; migration / permission / token / webhook paths
need only the external. External failed (logged) → internal alone clears. Measured before: 210 dispatches
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

Bare or `+`-prefixed lines ADD patterns; `-`-prefixed lines EXCLUDE paths the built-in list would match; `#` starts a comment. Read by `precommit-gate.sh`, `gate-reminder.sh`, and `session_state.py`; absent file = built-ins only; unreadable file fails open. The strongest seed: paths whose git history shows the highest bugfix-commit density — measure, don't guess.

### Test-tampering lint — `hooks/test-diff-lint.sh`

Warn-only helper invoked by `precommit-gate.sh` (not a registered event hook). It greps the staged diff for the machine-checkable half of qa-tester's REJECT list: focus/skip markers added on the way to green, deleted test cases, snapshot files refreshed with no test-logic change, DB mocks added under integration/e2e paths. Findings ride into the gate's warn/deny message; the lint itself never blocks — over-firing a hard block trains users to bypass gates. Every finding is accompanied by the HUMAN-ONLY caveat: whether expected values were derived from the spec or captured from current output is a judgment no grep can make, so a green lint must never be read as "tests are good". Since v2.103.0 it also flags a literal calendar date added under a test path — a written date expires and comes back as a red that is not a regression (measured: 41 of 125 test files in one project carried literal dates and 4 files went red on HEAD within a month); the fix is one frozen now.

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
- **`agent-sync.sh` (Codex-only, SessionStart, v2.75.0)** — the Codex plugin manifest has no `agents` component, so `codex plugin marketplace upgrade` alone never refreshed the 15 role agents or the `~/.codex/AGENTS.md` block. The plugin now bundles both (`plugins/rolepod-codex/agents/rolepod-*.toml` + `agents/AGENTS.rolepod.md`, rendered by `build/render.sh`); on session start the hook compares the plugin version with `~/.codex/agents/.rolepod-agents-version` and, when they differ, copies changed `rolepod-*.toml` files in, prunes retired ones (prefix-scoped — user agents are never touched), and replaces ONLY the `<!-- rolepod:start -->` … `<!-- rolepod:end -->` block of `~/.codex/AGENTS.md` (content outside the block is preserved byte-exact; no block → appended; file missing → created block-only). Fail-open and silent unless something changed (then one `additionalContext` line). `ROLEPOD_AGENT_SYNC_OFF=1` disables it; `install.sh` writes the same stamp so a fresh install is not re-synced on first launch; honors `CODEX_HOME`. Proven by `tests/integration/cases/codex-agent-sync.sh` against a sandboxed HOME. **Trust gate (Codex policy, verified 2026-09-03 against the official hooks reference):** Codex records hook trust against the hook definition's hash and *skips* new or changed plugin hooks until the user reviews them with `/hooks` — so the first session after this hook lands (or after its definition changes) needs that one-time trust; `codex exec` has `--dangerously-bypass-hook-trust` for vetted automation only.

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

Expected: 13 core hook scripts / 15 registrations (UserPromptSubmit × 1, SessionStart × 3, PreToolUse × 8, PostToolUse × 2, Stop × 1 — `session-lifecycle.sh` registers twice, `--lock`/`--unlock`).
