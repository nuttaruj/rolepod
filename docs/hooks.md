# Hooks reference

Rolepod ships 10 root bash hook scripts. Claude install copies all 10 scripts, then registers 9 rolepod entries in `~/.claude/settings.json`; `gitnexus-wrap.sh` is used only to patch the optional GitNexus plugin hook when GitNexus is installed. Each registered hook fires on a specific Claude Code event + matcher and either enforces a gate (exit 2 / `permissionDecision: deny`) or injects context (JSON `additionalContext`). All hooks are **self-guarded** — silent no-op when a dependency is missing.

Lead does not invoke these manually. They fire automatically.

## Event coverage

| Event | Matcher | Hooks |
|---|---|---|
| `SessionStart` | `startup\|resume` | `project-context-loader.sh`, `session-lock.sh` |
| `PreToolUse` | `Edit\|Write\|MultiEdit` | `gate-reminder.sh` |
| `PreToolUse` | `Bash` | `precommit-gate.sh`, `block-subagent-commit.sh` |
| `PreToolUse` | `Agent` | `cohesion-contract-check.sh` |
| `PostToolUse` | `Edit\|Write` | `verify-reminder.sh` |
| `PostToolUse` | `Bash` | `post-ship-detect.sh`, `gitnexus-wrap.sh` (when GitNexus plugin installed) |
| `Stop` | (no matcher) | `session-unlock.sh` |

## Per-hook reference

### `project-context-loader.sh` — SessionStart

Injects git context (branch, recent commits, hot files in last 7 days, reviewer availability) into Claude's session context. Lead sees this at the start of every conversation.

- **Trigger**: SessionStart `startup|resume`
- **Effect**: `additionalContext` with repo state
- **Self-guards**: not in a git repo → silent
- **Bypass**: none (always informational)

### `session-lock.sh` — SessionStart

Detects sibling Claude session(s) in the same worktree to prevent concurrent-edit stomp.

- **Trigger**: SessionStart `startup|resume`
- **Effect**: Writes own session lock to `~/.claude/.session-locks/<sha256(worktree)>/<session_id>.lock`. If sibling locks (<30 min old) detected → warns + suggests `git worktree add` path. Auto-prunes stale locks (>30 min).
- **Self-guards**: not in a git repo → silent; no sibling → silent
- **Bypass**: `ROLEPOD_ALLOW_SHARED_WORKTREE=1` (for intentional read-only review sessions)
- **Pair**: `session-unlock.sh` (Stop)

### `gate-reminder.sh` — PreToolUse Edit/Write/MultiEdit

Soft gate enforcing rolepod's S+T+F discipline before edits land. Three fixes:

- **Fix 3 (reviewer floor)**: high-risk path Edit when ≥2 high-risk edits + 0 reviewer agents dispatched → warn / block.
- **Fix 4 (auto-Careful banner)**: high-risk path edit → injects `/rolepod` mode reminder.
- **Fix 5 (RED-test discipline)**: high-risk path Edit when session has 0 test edits → warn / block.

- **Trigger**: PreToolUse `Edit|Write|MultiEdit`
- **Effect**: `additionalContext` warning OR `permissionDecision: deny` based on `ROLEPOD_GATES_SOFT`
- **Self-guards**: non-high-risk path → silent
- **Bypass**: `ROLEPOD_GATES_SOFT=1` (downgrade hard → warn), `ROLEPOD_GATES_PASSED=1` (single-edit override)

### `precommit-gate.sh` — PreToolUse Bash

Escalates to HARD block at `git commit` time when the session touched high-risk code but never produced a test edit, even if the final diff looks small.

- **Trigger**: PreToolUse `Bash`, command matches `git commit`
- **Effect**: `permissionDecision: deny` if high-risk path touched + 0 test edits in session
- **Self-guards**: non-commit Bash → silent; non-high-risk session → silent
- **Bypass**: `ROLEPOD_GATES_PASSED=1` (for legitimate test-less commits like docs)

### `block-subagent-commit.sh` — PreToolUse Bash

Sub-agents cannot run `git commit` / `git push` / `gh pr merge` / `gh pr create` / `git reset --hard` / `git push --force`. Lead owns version-control state after qa-tester + universal-reviewer pass.

- **Trigger**: PreToolUse `Bash`, `agent_id` field populated (sub-agent call)
- **Effect**: `permissionDecision: deny` with agent_type in reason
- **Self-guards**: Lead Bash (no `agent_id`) → silent
- **Bypass**: none — hard rule. Real-world failure (backend-developer committed bypassing qa-tester floor) motivated this.

### `cohesion-contract-check.sh` — PreToolUse Agent

When Lead is about to spawn the 2nd+ engineering agent within 10 events, requires a contract file (`contract.md` / `SPEC.md` / `cohesion.md` / `specs/*.md`) to exist in the session.

- **Trigger**: PreToolUse `Agent`
- **Effect**: `permissionDecision: deny` if 2+ agents spawned without contract
- **Self-guards**: 1st agent → silent; contract present → silent
- **Bypass**: `ROLEPOD_NO_CONTRACT=1` (single-domain Agent spawn legit)
- **Pair**: skill `write-plan` (cohesion-contract step)

### `verify-reminder.sh` — PostToolUse Edit/Write

After Lead edits, injects reminder to verify the change with evidence (test pass / screenshot / curl / log) before claiming done.

- **Trigger**: PostToolUse `Edit|Write`
- **Effect**: `additionalContext` reminder
- **Self-guards**: none
- **Bypass**: none (informational)

### `post-ship-detect.sh` — PostToolUse Bash

After ship cmd (`gh pr merge` / `git push main` / `git merge main`) touched ≥5 files in last 5 commits, auto-spawns `npx gitnexus analyze` in background (Lead-owned, no user nag). Block-seeded detection: first reindex without `--skip-agents-md` seeds the gitnexus block in CLAUDE.md; subsequent reindexes with `--skip-agents-md` freeze the block (no diff churn).

- **Trigger**: PostToolUse `Bash`, ship cmd pattern match + ≥5 files in last 5 commits
- **Effect**: `additionalContext` "GitNexus auto-reindex spawned in background. No user action needed."
- **Self-guards**: no `.gitnexus/` dir → silent; no `npx` on PATH → silent
- **Dedup**: shares once/day/repo marker with `gitnexus-wrap.sh` (`~/.claude/.gitnexus-bg-reindex-<repo>-<YYYYMMDD>`)
- **Bypass**: none (background spawn, doesn't block)

### `gitnexus-wrap.sh` — PreToolUse + PostToolUse Bash (GitNexus plugin only)

Wraps the GitNexus plugin's bare `gitnexus-hook.cjs` to:
1. Forward stdin/stdout transparently when no stale notice
2. Strip "index stale" notice + auto-spawn bg reindex (once/day/repo marker)
3. Auto-add `.gitnexus/` to `.git/info/exclude` (per-clone, NOT tracked) so analyze doesn't leave DB dir as untracked noise
4. Block-seeded detection: same logic as `post-ship-detect.sh`

Installed by `install.sh` only when the GitNexus plugin is detected.

- **Trigger**: PreToolUse + PostToolUse `Bash`
- **Effect**: stale notice → bg reindex; no notice → pass through
- **Self-guards**: plugin `.cjs` missing → silent no-op (uninstall safety)
- **Bypass**: none

### `session-unlock.sh` — Stop

Removes own session lock so the next session in this worktree doesn't see a phantom sibling. Pair to `session-lock.sh`.

- **Trigger**: Stop (no matcher)
- **Effect**: `rm -f $HOME/.claude/.session-locks/<sha256(worktree)>/<session_id>.lock`
- **Self-guards**: not in a git repo → silent; no `session_id` → silent
- **Bypass**: none (idempotent cleanup)

## Bypass envs — when to use

| Env | When |
|---|---|
| `ROLEPOD_GATES_SOFT=1` | Iterating on doctrine itself; want warnings instead of hard blocks for one session |
| `ROLEPOD_GATES_PASSED=1` | Legitimate single-edit on high-risk path (e.g. fixing a typo in `auth/` comment) |
| `ROLEPOD_NO_CONTRACT=1` | Single-domain Agent spawn that doesn't need cohesion contract (e.g. read-only research agent) |
| `ROLEPOD_ALLOW_SHARED_WORKTREE=1` | Intentional shared session (read-only review, paired exploration) |

Never set these globally — apply per-command only. Hard rules exist because real-world failures triggered them.

### Env namespace — `ROLEPOD_*` vs `CLAUDE_CODE_*`

Rolepod uses the `ROLEPOD_*` prefix exclusively for its bypass envs. This is **framework-scoped, not core-scoped** — completely separate from Anthropic's `CLAUDE_CODE_*` env namespace (which controls Claude Code's own runtime behavior).

| Prefix | Owner | Scope |
|---|---|---|
| `CLAUDE_CODE_*` | Anthropic / Claude Code | Core CLI behavior (e.g. `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD`) |
| `ROLEPOD_*` | Rolepod framework | Hook bypass + framework-level toggles |

No collision possible — different prefixes, different consumers. But: if rolepod ever needs to override a Claude Code core behavior, use the `CLAUDE_CODE_*` env directly per Anthropic docs — don't shadow it with a `ROLEPOD_*` wrapper.

## Why hooks, not just doctrine

Doctrine (CLAUDE.md text) tells the model what to do. Hooks **enforce** it. Models drift, especially under flow-state success cues — soft reminders get ignored. Hard blocks via `permissionDecision: deny` are the only mechanism that survives drift.

Three real failures that motivated hard hooks:
1. Sub-agent ran `git commit` after marking COMPLETED, bypassing qa-tester floor → `block-subagent-commit.sh`
2. Lead spawned 2+ parallel agents without writing a cohesion contract first, agents produced incompatible interfaces → `cohesion-contract-check.sh`
3. Concurrent Claude sessions on same worktree stomped each other's edits (last-write-wins) → `session-lock.sh`

## Why no "spec required" hook

Spec discipline is enforced via:
- `core/skills/write-spec/SKILL.md` — Iron Rule + approval gate + self-review
- `using-rolepod` router — Define phase exit evidence

Adding a `PreToolUse Bash` hook that checks for `docs/specs/<feature>.md` before Build-phase skills would:
- Duplicate `precommit-gate.sh`'s test-gate logic (already blocks high-risk commits without tests)
- Block legitimate trivial builds (typo fix, docs edit) that don't need a spec
- Force schema (`docs/specs/<feature>.md`) on user repos that might use different layouts

Decision: keep spec gating as doctrine. Router + skill text catches drift; hard hook adds friction without enough payoff.

## Installation

Hooks are copied to `~/.claude/hooks/` and registered in `~/.claude/settings.json` by `install.sh`. Re-running install is idempotent: existing entries are upserted by command path, not duplicated.

To verify registration:
```bash
jq '.hooks' ~/.claude/settings.json
```

Expected: 2× SessionStart + 4× PreToolUse + 2× PostToolUse + 1× Stop = 9 rolepod hooks (10 if GitNexus plugin installed → `gitnexus-wrap.sh` patches the plugin's bare hook registration).
