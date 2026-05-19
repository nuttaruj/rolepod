# Hooks reference

Rolepod ships **8 bash hook scripts** — 6 core in `hooks/` and 2 GitNexus add-on in `hooks/optional/gitnexus/`. Claude install copies all 8 (the optional scripts always ship so they are auditable), then registers **7 core entries** in `~/.claude/settings.json` by default (2× `SessionStart` + 4× `PreToolUse` + 1× `Stop`). When the GitNexus plugin is detected at install time, an additional `PostToolUse Bash` entry registers `optional/gitnexus/post-ship-detect.sh` and `optional/gitnexus/gitnexus-wrap.sh` patches the plugin's bare hook (= 8 entries in a GitNexus-enabled install). Each registered hook fires on a specific Claude Code event + matcher and either enforces a gate (`permissionDecision: deny`) or injects context (JSON `additionalContext`). All hooks are **self-guarded** — silent no-op when a dependency is missing.

Lead does not invoke these manually. They fire automatically.

## Hook categories — Core vs Optional add-on

| Category | Hooks | Purpose |
|---|---|---|
| **Core enforcement** | `block-subagent-commit`, `cohesion-contract-check`, `gate-reminder`, `precommit-gate` | Hard / soft blocks on discipline violations (high-risk path, parallel-without-contract, sub-agent commit, schema-bound new file) |
| **Core context** | `project-context-loader` | Inject git state at SessionStart |
| **Core session safety** | `session-lifecycle` | SessionStart lock + Stop unlock — prevents concurrent-edit stomp |
| **Optional add-on (GitNexus)** | `post-ship-detect`, `gitnexus-wrap` | Auto-reindex when GitNexus is present in repo. Live in `hooks/optional/gitnexus/`; register only when the GitNexus plugin is detected at install time |
| **Optional add-on (MemPalace × Codex)** | `codex-session-start` | Bridge Codex sessions into MemPalace cross-session recall. Lives in `hooks/optional/mempalace/`; registered in the Codex plugin cache `hooks.json` at install time only when `command -v mempalace` succeeds AND target is a real Codex global install. Codex Stop / PreCompact equivalents not shipped — Codex 0.130 plugin hook schema only exposes SessionStart / PreToolUse / PostToolUse |

Core hooks register on every install. Optional GitNexus hooks ship at the path for auditability but only register in `settings.json` when the GitNexus plugin is detected.

PR 6 dropped `verify-reminder.sh` (PostToolUse Edit/Write per-edit nag). The same discipline lives in:
- skill `check-work` — Iron Rule + evidence-required output contract
- `precommit-gate.sh` — hard-blocks commit on high-risk + zero tests
- skill `using-rolepod` — Verify phase exit gate

A per-edit reminder hook duplicated all three without enforcement teeth — so it was removed instead of replicated.

## Event coverage

| Event | Matcher | Hooks |
|---|---|---|
| `SessionStart` | `startup\|resume` | `project-context-loader.sh`, `session-lifecycle.sh --lock` |
| `PreToolUse` | `Edit\|Write\|MultiEdit` | `gate-reminder.sh` |
| `PreToolUse` | `Bash` | `precommit-gate.sh`, `block-subagent-commit.sh` |
| `PreToolUse` | `Agent` | `cohesion-contract-check.sh` |
| `PostToolUse` | `Bash` | `optional/gitnexus/post-ship-detect.sh` + `optional/gitnexus/gitnexus-wrap.sh` (only when GitNexus plugin installed) |
| `Stop` | (no matcher) | `session-lifecycle.sh --unlock` |

## Per-hook reference

### `project-context-loader.sh` — SessionStart (core)

Inject git context at session start.

- **Effect**: `additionalContext` with repo name, branch, dirty count, recent commits (last 5), hot files (last 7 days). Also silently auto-recovers GitNexus DB if the plugin's bg reindex wedged it (once/day/repo).
- **Self-guards**: not in a git repo → silent. GitNexus recovery only fires when `.gitnexus/` exists + a wedged-log marker is present.
- **What this hook no longer does** (PR 5 slim): GitNexus-missing nag, MemPalace first-session nag, external reviewer banner. Add-on availability is documented in README + skills, not nagged per SessionStart.

### `session-lifecycle.sh --lock` — SessionStart (core)

Detect sibling Claude session(s) in the same worktree to prevent concurrent-edit stomp.

- **Effect**: write own lock to `~/.claude/.session-locks/<sha256(worktree)>/<session_id>.lock`. If sibling locks (<30 min old) detected → warn + suggest `git worktree add` path. Auto-prune stale locks (>30 min).
- **Self-guards**: not in a git repo → silent; no sibling → silent.
- **Bypass**: `ROLEPOD_ALLOW_SHARED_WORKTREE=1` (for intentional read-only review sessions).
- **Pair**: same script invoked with `--unlock` on Stop.

### `gate-reminder.sh` — PreToolUse Edit/Write/MultiEdit (core)

Schema-bound + high-risk edit guard. Silent on normal code edits (PR 5 slim — generic Q1-Q4 reminder moved to CLAUDE.md / AGENTS.md / using-rolepod skill, read once per session, not per edit).

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

### `optional/gitnexus/post-ship-detect.sh` — PostToolUse Bash (optional add-on)

After ship cmd (`gh pr merge` / `git push main` / `git merge main`) touched ≥5 files in last 5 commits, auto-spawns `npx gitnexus analyze` in background (Lead-owned, no user nag).

- **Registration**: only registered in `settings.json` when the GitNexus plugin is detected at install time. Script always ships at `hooks/optional/gitnexus/post-ship-detect.sh` for auditability.
- **Effect**: `additionalContext` "GitNexus auto-reindex spawned in background. No user action needed."
- **Self-guards**: no `.gitnexus/` dir → silent; no `npx` on PATH → silent.
- **Dedup**: shares once/day/repo marker with `gitnexus-wrap.sh`.
- **Bypass**: none (background spawn, doesn't block).

### `optional/gitnexus/gitnexus-wrap.sh` — PreToolUse + PostToolUse Bash (optional add-on)

Wraps the GitNexus plugin's bare `gitnexus-hook.cjs` to: forward stdin/stdout transparently when no stale notice; strip "index stale" notice + auto-spawn bg reindex (once/day/repo marker); auto-add `.gitnexus/` to `.git/info/exclude`; block-seeded detection.

`install.sh` patches the GitNexus plugin's hook entry only when the plugin is detected — script is shipped but the registration swap only happens when the plugin is present.

- **Self-guards**: plugin `.cjs` missing → silent no-op (uninstall safety).
- **Bypass**: none.

### `optional/mempalace/codex-session-start.sh` — Codex SessionStart (optional add-on)

Bridge Codex sessions into MemPalace cross-session knowledge-graph recall. Calls `mempalace hook run --hook session-start --harness codex` (with `--harness claude-code` fallback for older MemPalace releases).

- **Registration**: only registered in the Codex plugin cache `hooks/hooks.json` when `command -v mempalace` succeeds at install time AND target is a real Codex global install (not a temp `ROLEPOD_TARGET`). Idempotent — re-install strips + re-adds.
- **Self-guards**: `mempalace` binary missing at runtime → exit 0 silently. Survives MemPalace uninstall without leaving noisy hooks.
- **Codex caveat**: the entry is registered in `hooks.json` but Codex itself only fires plugin hooks after `codex features enable plugin_hooks` (default flag: `under development, false`).
- **Why no Stop / PreCompact equivalents**: Codex 0.130 plugin hook schema exposes `SessionStart`, `PreToolUse`, `PostToolUse` only — no Stop event for "session ended", no PreCompact for "context compressed". When upstream Codex adds those events, mirror this script for `codex-stop.sh` / `codex-precompact.sh`.
- **Gemini**: not auto-wired in rolepod yet. MemPalace upstream does not yet support `--harness gemini`; current Gemini integration is manual / MCP-assisted. README documents the limitation.

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
- **1 optional add-on** mirror at `hooks/optional/gitnexus/post-ship-detect.sh` — ships but not registered by default; enable manually if GitNexus is adopted on Codex.

`block-subagent-commit`, `cohesion-contract-check`, `gitnexus-wrap`, `session-lifecycle` stay Claude-only (Codex has no `Agent` event API and no `Stop` event for unlock; the GitNexus plugin model also differs per Codex).

`tests/static/lean-surface.sh` enforces byte-exact parity between root and Codex adapter for the shared hooks (3 core + 1 optional/gitnexus) — any drift fails the release gate.

## Installation

Hooks are copied to `~/.claude/hooks/` and registered in `~/.claude/settings.json` by `install.sh`. Re-running install is idempotent — existing entries are upserted by command path, not duplicated. Migration steps strip the pre-PR-5 `session-lock.sh` / `session-unlock.sh` commands (replaced by `session-lifecycle.sh --lock` / `--unlock`) and the pre-PR-6 `verify-reminder.sh` + root `post-ship-detect.sh` commands.

To verify registration:
```bash
jq '.hooks' ~/.claude/settings.json
```

Expected by default: 2× SessionStart + 4× PreToolUse + 1× Stop = 7 rolepod entries. When the GitNexus plugin is detected at install time, an additional 1× PostToolUse Bash entry registers `optional/gitnexus/post-ship-detect.sh` (= 8 entries total), and `optional/gitnexus/gitnexus-wrap.sh` swaps the GitNexus plugin's bare hook command.
