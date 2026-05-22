# Hooks reference

Rolepod ships **7 core bash hook scripts** in `hooks/`. Each CLI adapter declares these in a plugin/extension `hooks/hooks.json` — Claude, Codex, and Gemini all use the same `hooks/hooks.json` form. All hooks are **self-guarded** — silent no-op when a dependency is missing.

Lead does not invoke these manually. They fire automatically.

## Hook categories — All core (no add-on hooks)

| Category | Hooks | Purpose |
|---|---|---|
| **Always-on** | `always-on-loader` | Inject the rolepod always-on judgment core as SessionStart context |
| **Enforcement** | `block-subagent-commit`, `cohesion-contract-check`, `gate-reminder`, `precommit-gate` | Hard / soft blocks on discipline violations (high-risk path, parallel-without-contract, sub-agent commit, schema-bound new file) |
| **Context** | `project-context-loader` | Inject git state at SessionStart |
| **Session safety** | `session-lifecycle` | SessionStart lock + Stop unlock — prevents concurrent-edit stomp |

All 7 hooks register on every Claude install. MemPalace and GitNexus integrate via their own vendor plugins/CLI, not rolepod hooks.

PR 6 dropped `verify-reminder.sh` (PostToolUse Edit/Write per-edit nag). The same discipline lives in:
- skill `check-work` — Iron Rule + evidence-required output contract
- `precommit-gate.sh` — hard-blocks commit on high-risk + zero tests
- skill `using-rolepod` — Verify phase exit gate

A per-edit reminder hook duplicated all three without enforcement teeth — so it was removed instead of replicated.

## Event coverage

| Event | Matcher | Hooks |
|---|---|---|
| `SessionStart` | `startup\|resume` | `always-on-loader.sh`, `project-context-loader.sh`, `session-lifecycle.sh --lock` |
| `PreToolUse` | `Edit\|Write\|MultiEdit` | `gate-reminder.sh` |
| `PreToolUse` | `Bash` | `precommit-gate.sh`, `block-subagent-commit.sh` |
| `PreToolUse` | `Agent` | `cohesion-contract-check.sh` |
| `Stop` | (no matcher) | `session-lifecycle.sh --unlock` |

## Per-hook reference

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
- **What this hook does not do**: no add-on detection, no vendor-tool recovery, no first-session nag, no external-reviewer banner. Add-on availability is documented in README + skills, never nagged per SessionStart.

### `session-lifecycle.sh --lock` — SessionStart (core)

Detect sibling Claude session(s) in the same worktree to prevent concurrent-edit stomp.

- **Effect**: write own lock to `~/.claude/.session-locks/<sha256(worktree)>/<session_id>.lock`. If sibling locks (<30 min old) detected → warn + suggest `git worktree add` path. Auto-prune stale locks (>30 min).
- **Self-guards**: not in a git repo → silent; no sibling → silent.
- **Bypass**: `ROLEPOD_ALLOW_SHARED_WORKTREE=1` (for intentional read-only review sessions).
- **Pair**: same script invoked with `--unlock` on Stop.

### `gate-reminder.sh` — PreToolUse Edit/Write/MultiEdit (core)

Schema-bound + high-risk edit guard. Silent on normal code edits (PR 5 slim — the generic Q1-Q4 reminder lives in the always-on core / AGENTS.md / the using-rolepod skill, read once per session, not per edit).

Fires output ONLY when:
1. **Schema-bound NEW file** (plugin.json, marketplace.json, hooks.json, extension manifests) → soft warn: WebFetch spec FIRST.
2. **High-risk path** (auth / billing / migration / secret / crypto / token / oauth / jwt / sso / saml / webhook / stripe / paypal / charge / invoice) → soft warn + auto-Careful banner with reviewer list (qa-tester + Codex/Gemini when binaries present).
3. **High-risk path + discipline drift** → HARD BLOCK:
   - 1st+ high-risk edit + 0 test edits in session → block (RED-test discipline).
   - 2nd+ high-risk edit + 0 reviewer agents dispatched → block (reviewer floor).

- **Self-guards**: docs / lockfiles / non-high-risk code → silent.
- **Bypass**: `ROLEPOD_GATES_SOFT=1` (downgrade hard → warn), `ROLEPOD_GATES_PASSED=1` (single-edit override).

### `precommit-gate.sh` — PreToolUse Bash (core)

Escalates to HARD block at `git commit` time when the session touched high-risk code but never produced a test edit.

- **Effect**: `permissionDecision: deny` if high-risk path touched + 0 test edits in session.
- **Self-guards**: non-commit Bash → silent; non-high-risk session → silent.
- **Bypass**: `ROLEPOD_GATES_PASSED=1` (for legit test-less commits like docs).

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

### `session-lifecycle.sh --unlock` — Stop (core)

Removes own session lock so the next session in this worktree does not see a phantom sibling. Same script as the SessionStart `--lock` invocation, different mode flag.

- **Effect**: `rm -f $HOME/.claude/.session-locks/<sha256(worktree)>/<session_id>.lock`.
- **Self-guards**: not in a git repo → silent; no `session_id` → silent.
- **Bypass**: none (idempotent cleanup).

## Bypass envs — when to use

| Env | When |
|---|---|
| `ROLEPOD_GATES_SOFT=1` | Iterating on doctrine itself; want warnings instead of hard blocks for one session |
| `ROLEPOD_GATES_PASSED=1` | Legitimate single-edit on high-risk path (e.g. fixing a typo in `auth/` comment) |
| `ROLEPOD_NO_CONTRACT=1` | Single-domain Agent spawn that doesn't need cohesion contract (e.g. read-only research agent) |
| `ROLEPOD_ALLOW_SHARED_WORKTREE=1` | Intentional shared session (read-only review, paired exploration) |

Never set these globally — apply per-command only. Hard rules exist because real-world failures triggered them.

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

Adding a `PreToolUse Bash` hook that checks for `docs/specs/<feature>.md` before Build-phase skills would duplicate `precommit-gate.sh`, block legitimate trivial builds, and force a layout schema on user repos. Decision: keep spec gating as doctrine.

## Root vs Codex adapter parity

Root `hooks/*.sh` is canonical. The Codex adapter mirrors only the hooks whose events Codex supports (`SessionStart`, `PreToolUse apply_patch|Bash`, `PostToolUse Bash`):

- **3 core** byte-exact mirrors: `gate-reminder.sh`, `precommit-gate.sh`, `project-context-loader.sh`.

`always-on-loader`, `block-subagent-commit`, `cohesion-contract-check`, `session-lifecycle` stay Claude-only (`always-on-loader` is unnecessary on Codex/Gemini — they load their always-on core natively from `AGENTS.md` / `GEMINI.md`; Codex also has no `Agent` event API and no `Stop` event for unlock).

`tests/static/lean-surface.sh` enforces byte-exact parity between root and Codex adapter for the shared hooks (3 core) — any drift fails the release gate.

## Installation

Hooks are shipped in the rolepod plugin tree (`~/.claude/plugins/rolepod/hooks/`) and declared in the plugin's `hooks/hooks.json` (the canonical plugin-root form). Re-running install is idempotent. Migration steps (pre-2.0 installs) strip any legacy hook entries from `~/.claude/settings.json`.

To verify installation:
```bash
claude plugin list
# Should show "rolepod" as enabled

claude plugin details rolepod@rolepod
# Component inventory should list a Hooks line covering SessionStart, PreToolUse, Stop
```

Expected: 7 core hooks (SessionStart × 3, PreToolUse × 3, Stop × 1).
