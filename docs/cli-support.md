# Rolepod — Per-CLI Support Matrix

Status of rolepod features across the three supported coding CLIs.

| Capability | Claude Code | Codex CLI | Gemini CLI |
|---|---|---|---|
| Always-on instructions | `~/.claude/CLAUDE.md` (native) | `~/.codex/AGENTS.md` (native) | `~/.gemini/GEMINI.md` (native) |
| Lazy-load rules (Read on trigger) | full | full (manual) | full (manual) |
| Skills auto-pull | full | manual (Lead reads `core/skills/<name>/SKILL.md`) | manual |
| Subagents (parallel team) | full Task / SendMessage | Lead-only (out-of-band `codex exec` optional) | Lead-only |
| Hooks (auto reminders) | full (4 hooks register in `settings.json`) | wrapper script preamble (opt-in) | wrapper script preamble (opt-in) |
| Slash commands (`/careful`) | full | `ROLEPOD_CAREFUL=1` env via wrapper | `[CAREFUL MODE]` prompt prefix or env |
| Plugin manifest | `.claude-plugin/manifest.json` (verified spec) | `manifest.json` (best-effort, schema unverified) | none — content lives inside GEMINI.md |
| MemPalace / GitNexus integration | full hook coverage | manual MCP invocation | manual MCP invocation |
| MCP server config | global + per-plugin | global (`codex mcp`) | global (`gemini mcp`) |

## What "best-effort manifest" means for Codex

The Codex CLI plugin manifest format is not publicly documented as of
2026-05-10. `codex plugin --help` and `codex plugin marketplace --help`
expose only `add` / `remove` / `upgrade` subcommands without a schema reference,
and there is no published JSON schema in the OpenAI Codex repos that we can
verify against. `adapters/codex/manifest.json` therefore ships as a stub:

- The shape mirrors the Claude Code plugin manifest with renamed fields
- A `_comment` field flags this as a stub
- The file is copied to `~/.codex/manifest.json` for forward-compat — a future
  `codex plugin marketplace add` flow can be wired up once the spec lands

If the manifest causes Codex to error on startup, delete it — `~/.codex/AGENTS.md`
remains the load-bearing file.

## Wrapper scripts (opt-in)

Both Codex and Gemini lack a hook system, so they ship a small wrapper that
prepends a per-turn rule reminder before forwarding to the binary:

- `~/.codex/bin/rolepod-codex.sh` (after `--target=codex` install)
- `~/.gemini/bin/rolepod-gemini.sh` (after `--target=gemini` install)

Add the bin dir to PATH and use the wrapper instead of the bare CLI for the
reminder behavior. Bare CLI invocation still works — rules from AGENTS.md /
GEMINI.md remain in effect, just without the per-turn pressure model.

## Why no full subagent emulation on Codex / Gemini

The Claude Code `Task` / `SendMessage` tools dispatch a fresh, isolated context
to a specialist agent and merge the result. Codex's `codex exec` and Gemini
have no equivalent — output merging, parallel execution, and shared-state
semantics differ enough that emulation produces unpredictable behavior. We
ship Lead-only mode by default and let the user spawn out-of-band reviewers
manually when needed.

## Verification status — what's confirmed locally

| Item | Verified by |
|---|---|
| Codex binary path | `which codex` → `~/.nvm/versions/node/v24.14.0/bin/codex` |
| Codex AGENTS.md path | `~/.codex/AGENTS.md` exists (pre-populated by Codex) |
| Codex plugin schema | NOT verified — assumed stub format |
| Gemini binary path | `which gemini` → `~/.nvm/versions/node/v24.14.0/bin/gemini` |
| Gemini GEMINI.md path | `~/.gemini/GEMINI.md` exists |
| Wrapper scripts | `bash -n` clean; first-run banner tested |
| Render output | `build/rendered/{claude,codex,gemini}/` populated, no INCLUDE leaks |
| Snapshot test (Claude) | `diff` 0-byte vs pre-Phase-2.2 CLAUDE.md and 18 agent files |

## Follow-up after Phase 2.2

- Wire the Codex manifest into `codex plugin marketplace add` once the schema
  is published
- Investigate Gemini's `extensions` system as a potential richer integration
  surface than just `GEMINI.md`
- Port MemPalace / GitNexus hooks to Codex+Gemini if/when those CLIs gain
  hook event APIs
