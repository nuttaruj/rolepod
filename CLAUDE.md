<!-- Thin stub: the Claude always-on core arrives through the plugin's SessionStart hook (hooks/always-on-loader.sh emits the rendered core). A full block here would load twice. Install rolepod globally to dogfood; `make render` refreshes build artifacts. -->

# Gate cadence

- Editing: only the check that covers the file — `make test-lean-surface` (caps, invariants), `bash tests/static/<x>.sh`, `bash -n hooks/<x>.sh` + its case in `tests/integration/cases/`; a slow case file (`hook-behavior.sh`, `cross-family-runner.sh`) takes `ROLEPOD_CASE=<banner regex>` to run just the section for the hook/script just edited.
- Task Command: every case file that names a file the task changes — `grep -rl <name> tests/` per file (`ROLEPOD_CASE=` for a section of a slow file); the owner ends with the commit check once — `make render && git add -A && make test-static` (~22 s) — so integration never fails on a static pin.
- Commit: `make render && git add -A && make test-static` once; read the exit code, never `| grep`.
- Release: the plan's combined review done, then `make test-all` once, then `docs/release-checklist.md`.
- After the release: the closing line proposes /compact (or a fresh session) before the next request.
- One release per completed request that changed `core/ hooks/ scripts/ adapters/ plugins/`; docs-only = commit + push. Earlier only when the next ticket needs the hook or script just shipped.
- External member: `--detach`, next task, one `--collect` (it waits).
- After a dispatch: next unblocked task, never idle on a reviewer.
- Worktree only for a parallel task owner. R2 → a task owner on main from the Lead's 3-5 line brief (goal, done-when, Command — the Lead never pre-explores); Lead self-do is R1 only.
- R3 (multi-file) dispatches the task owner the plan names (hooks/scripts → devops-sre, python lib → backend-developer, docs → content-strategist); the Lead plans, spot-checks, commits.
- Docs task (R1 at any size): ≤ ~5 edit sites with the exact strings already in the plan → `Owner: Lead`; more sites, free prose or repo-wide docs → content-strategist (cheap tier), tracks in parallel, Lead spot-check. Payload doctrine (`core/skills`, `core/fragments`, hook messages) → the contract carries the canonical sentences; expect one fix round.
- Edits go through the CLI's Edit/Write tools, never a Bash heredoc or sed: the edit-time hooks (self-do nudge, write scope, edit ledger, test-edit count) see tool edits only.
