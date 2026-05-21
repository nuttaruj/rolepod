# PLAN — rolepod clean pure-plugin redesign

Spec: `docs/specs/clean-plugin-redesign.md` (APPROVED 2026-05-21)
Shape: 7 vertical slices, sequential, one PR per slice. Riskiest first.
Execution: sequential — each slice depends on the prior; no parallel agents,
no cohesion contract needed. Each slice leaves rolepod fully working.

## Progress

- **Slice 0 — CI repair (unplanned, PR #17, merged 2026-05-21).** PR #16 surfaced
  pre-existing CI rot: the install round-trip lane in `.github/workflows/installer.yml`
  asserted the old pre-plugin layout. Fixed all stale paths + dropped the obsolete
  "Claude byte-identical" snapshot test + fixed an `install.sh` `COMMAND_NAMES`
  unbound-variable crash (macOS bash 3.2 uninstall path). Commit `941acfd`.
- **Slice 1 — DONE (PR #16, merged 2026-05-21).** Commit `e9a7cd2`. SessionStart
  always-on hook proven: `hooks/always-on-loader.sh` + `hooks/always-on-core.md`
  (~3KB judgment core) + `tests/static/always-on-hook.sh`. Wired in
  `adapters/claude/hooks.json`; `build/render.sh` copies `hooks/*.md` into the plugin.
- **Slice 2 — DONE (PR #18, merged 2026-05-21).** Commits `ae85d3e` + `7088088`.
  Claude install is now a pure plugin: no `~/.claude/CLAUDE.md` managed block,
  no `rules/always-on/` copy. `install.sh` Claude path drops `update_managed_block`,
  copies only `rules/code/` + `rules/test/`, strips a stale `always-on/` dir +
  `rules/INDEX.md`, runs `remove_managed_block` as an upgrade migration.
  `render_claude` no longer emits `CLAUDE.md`; `adapters/claude/CLAUDE.md.tmpl`
  deleted. Tests + `.github/workflows/installer.yml` updated for the pure-plugin
  contract. Known follow-up: `core/fragments/team-trigger.md` is now an orphaned
  fragment (was Claude-tmpl-only) — clean up in a later fragment-fold slice.
- **Slice 3 — DONE (not yet committed, 2026-05-21).** Gate checklists folded
  into the phase skills they belong to: `finish-work` pre-merge gate now carries
  the full S1-S5 + T1-T6 checklists (F1-F5 references the `check-work` gate to
  avoid duplication); `implement-plan` §4 carries the Q1-Q4 delegation test;
  `check-work` gains a §6 F1-F5 failure-mode gate. CI lanes were already present
  in `finish-work` §2 from a prior PR — no net-new (dedup). Operational notes:
  added a "3rd PR / 3rd agent on the same surface" ship hard-stop; the rest is
  already distributed across skills. `lean-surface.sh` gains a ≤220-line cap
  guard for the 9 phase skills (router excluded). Touched skills: finish-work
  176, implement-plan 157, check-work 165 — all ≤220. Static + 8 integration
  cases green; gate enforcement (`high-risk-gates`, `ship-gate`) intact. The
  gate fragments stay (Codex/Gemini tmpls still use them — folded out in Slice 6).
- **Slice 4 — DONE (not yet committed, 2026-05-21).** Path-scoped rules folded
  into the phase skills and the `core/rules/code/` + `core/rules/test/` dirs
  removed. Net-new was small — slice 3 + the existing skills already covered
  most of it. Folds: `implement-plan` §3 gained quality reflexes (comments
  WHY-only · one source of truth · new-dependency justification · no DB mocks
  in integration tests · GitNexus-if-installed); `finish-work` §2 CI table
  gained a per-lane content column. Removed 5 files: `code/code-quality.md`,
  `code/code-intel.md`, `code/code-intel-workflow.md`, `test/testing.md`,
  `INDEX.md`. `install.sh` no longer copies or mkdir's `rules/` — it only
  strips stale rolepod rules on upgrade; verification + `installer.yml` +
  `install-parity.sh` updated to the no-rules-copy contract; `lean-surface.sh`
  gained an anti-drift guard that `core/rules/code` + `core/rules/test` stay
  deleted. Static + 8 integration + CI install repro green. Known follow-up:
  the gate fragments (`gates-s1-s5.md`, `gates-t1-t5.md`) still carry stale
  `Details: ~/.claude/rules/...` pointers — fixed when slice 6 reworks the
  Codex/Gemini always-on surface. `core/rules/` now holds only `always-on/`.
- **NEXT: Slice 5.** Inline `agent-protocol.md` into each of the 18 agent
  files; drop the skill-index + agent-roster from the always-on surface.

## Files in scope

- `hooks/` — new `always-on-loader.sh`; existing `session-lifecycle.sh`,
  `project-context-loader.sh`, `precommit-gate.sh`, `gate-reminder.sh` (reference)
- `adapters/claude/` — `hooks.json`, `CLAUDE.md.tmpl`, `.claude-plugin/`
- `adapters/codex/` — `AGENTS.md.tmpl`, hooks, plugin manifest
- `core/rules/always-on/` — `verify-first.md`, `communication.md`,
  `code-search.md`, `agent-protocol.md`
- `core/rules/code/` + `core/rules/test/` — removed after fold (5 files)
- `core/skills/` — `finish-work`, `implement-plan`, `check-work`,
  `review-code`, `simplify-code`, `write-spec` SKILL.md
- `core/agents/*.md` — 18 agent files
- `build/render.sh` — `render_claude`, `render_codex`, `generate_skill_index*`,
  `generate_agent_roster*`
- `install.sh` — Claude path + Codex path
- `tests/static/lean-surface.sh`, `tests/skill-triggering/`, `tests/integration/`
- Docs — `README.md`, `docs/cli-support.md`, `CHEATSHEET.md`, `docs/hooks.md`,
  `docs/release-checklist.md`, `.claude-plugin/plugin.json`

## Slices (ordered)

### Slice 1 — Prove the SessionStart always-on hook (Claude)  [RISKIEST]

The load-bearing unknown: does hook-delivered always-on actually work
end-to-end. Build it WITHOUT removing the CLAUDE.md block yet — fully reversible.

- New `hooks/always-on-loader.sh` — reads a trimmed judgment-core `.md` from the
  plugin dir, emits `{hookSpecificOutput:{hookEventName:"SessionStart",
  additionalContext:...}}`. Pattern copied from `session-lifecycle.sh:94-104`.
- New judgment-core source file (first-cut content; final trim in Slice 2).
- Wire into `adapters/claude/hooks.json` SessionStart array.
- `build/render.sh` renders the new hook + content into the plugin.
- Test: smoke — `echo '{}' | bash hooks/always-on-loader.sh` returns valid JSON;
  payload byte size ≤ 5120. Add as `tests/static/` check. Plus a manual Claude
  session: confirm the core appears in context.
- Done: hook fires, core in context, size within budget, old block still present.

### Slice 2 — Trim the judgment core; drop the CLAUDE.md block (Claude)

Hook proven → the managed block is now redundant. Trim, then stop writing it.

- Trim `always-on/verify-first.md` + `communication.md` + `code-search.md` to
  judgment core (target ≤ 5KB combined for the hook payload).
- `install.sh` Claude path — remove the `update_managed_block` CLAUDE.md call
  and the `rules/` copy.
- `adapters/claude/CLAUDE.md.tmpl` + `render.sh render_claude` — stop emitting
  the gate block as a managed block.
- Test: `install.sh --target=claude --dry-run` shows no CLAUDE.md write, no
  rules/ copy; `tests/static/lean-surface.sh` passes; hook payload ≤ 5KB.
- Done: clean Claude install does not touch `~/.claude/CLAUDE.md` or `rules/`.

### Slice 3 — Redistribute gates / CI / operational notes into phase skills

- Fold S/T/F/Q gates + CI lanes + operational notes into `finish-work`
  (S/T/F + CI), `implement-plan` (Q1-Q4), `check-work` (F1-F5). Condense +
  dedupe against existing skill content.
- Test: `tests/static/lean-surface.sh` (skill structure + line bounds) passes;
  each touched SKILL.md ≤ 220 lines; `bash hooks/precommit-gate.sh` test still
  blocks (gate enforcement intact).
- Done: gate prose lives in its phase skill; hooks still hard-enforce.

### Slice 4 — Fold code/test path rules into phase skills

- `code-quality.md` → implement-plan / review-code / simplify-code (net-new
  only, ~10-20 lines each).
- `code-intel.md` + `code-intel-workflow.md` → condense to ~30 lines ("if
  GitNexus installed → use it for X") across relevant skills + the always-on
  picker.
- `testing.md` → CI 3-phase to finish-work; T1-T6/matrix to implement-plan;
  quality/T6 to check-work.
- Remove `core/rules/code/` + `core/rules/test/` (5 files).
- Update `tests/static/lean-surface.sh` (it asserts rule counts/paths).
- Test: static tests updated + pass; `tests/skill-triggering/run.sh` passes;
  no `rules/` shipped; skills ≤ 220 lines.
- Done: no path-scoped rules directory; content folded + deduped.

### Slice 5 — Inline agent-protocol; drop skill-index + agent-roster

- `agent-protocol.md` → condensed section inlined into each of 18
  `core/agents/*.md`.
- Remove `generate_skill_index*` + `generate_agent_roster*` output from the
  always-on surface in `render.sh` (Claude surfaces both natively).
- Test: static — every agent file carries the protocol section; agent count
  check; `tests/static/lean-surface.sh` passes.
- Done: always-on surface carries no skill index / roster; agents self-contained.

### Slice 6 — Codex parity

- Apply Slices 1-5 equivalents to the Codex target: SessionStart hook delivers
  the always-on core; reduce `adapters/codex/AGENTS.md.tmpl` block as far as
  Codex allows; `install.sh` Codex path emits a `plugin_hooks` enable notice;
  handle agents (not a Codex plugin component — keep current Codex agent
  handling, do not regress it).
- `render.sh render_codex` updated.
- Test: `build/render.sh --target=codex` output check; AGENTS.md reduced;
  static tests pass.
- Done: Codex install is plugin-based; always-on via hook; notice present.

### Slice 7 — install.sh cleanup + docs + version bump

- Reduce `install.sh` to plugin-install for Claude + Codex (Gemini path
  untouched).
- Update `README.md`, `docs/cli-support.md`, `CHEATSHEET.md`, `docs/hooks.md`,
  `docs/release-checklist.md`.
- `.claude-plugin/plugin.json` — bump version, rewrite the description
  (drop the "always-on CLAUDE.md gate block + rules/ are script-installed"
  clause; it is no longer true).
- Test: `install.sh --dry-run` for claude + codex; `tests/static/lean-surface.sh`
  (it asserts doc claims) passes after doc updates.
- Done: docs match the new architecture; one-command install documented.

## High-risk surfaces

- Slice 2 (install.sh) + Slice 6 (Codex install) — broken install hits every
  user. Mitigation: `--dry-run` verification before any real install; keep
  Slice 1 reversible.
- Slices 3-5 — gate enforcement must not regress. Mitigation: run the
  precommit-gate / gate-reminder hook tests after each fold.
- Gemini render path must stay green through every slice.

## Agent routing

Lead-executable meta work (rolepod editing its own skills/hooks/build). Optional
delegation: `devops-sre` for the hook/build/install slices (1, 2, 6, 7);
`tech-writer` for Slice 7 docs. qa-tester reviews the gate-enforcement test
evidence after Slices 3-5.

## Done criteria (whole plan)

All Spec success criteria met; `tests/static/lean-surface.sh` +
`tests/skill-triggering/` + `tests/integration/` green; `claude plugin
install/uninstall rolepod` is the complete Claude flow; no write to
`~/.claude/CLAUDE.md` or `~/.claude/rules/`; Codex equivalent; Gemini untouched.

## Risks

- additionalContext eviction on compaction → re-inject via SessionStart:compact
  (rolepod already does this; verify in Slice 1).
- Codex `plugin_hooks` opt-in → Slice 6 install notice; resolve fallback there.
- 18-agent edit (Slice 5) is mechanical but wide — script the inline if possible.
