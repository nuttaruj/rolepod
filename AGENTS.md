<!-- Thin stub: the Codex core is the managed block in ~/.codex/AGENTS.md (install.sh --target=codex, rendered from adapters/codex/AGENTS.md.tmpl). A full block here would load twice. -->

# Gate cadence

- Editing: only the check that covers the file — `make test-lean-surface` (caps, invariants), `bash tests/static/<x>.sh`, `bash -n hooks/<x>.sh` + its case in `tests/integration/cases/`.
- Task Command: only the case files the task touches (`ROLEPOD_CASE=` for a section of a slow file); the owner ends with the commit check once — `make render && git add -A && make test-static` (~22 s) — so integration never fails on a static pin.
- Commit: `make render && git add -A && make test-static` once; read the exit code, never `| grep`.
- Release: the plan's combined review done, then `make test-all` once, then `docs/release-checklist.md`.
- After the release: the closing line proposes /compact (or a fresh session) before the next request.
- One release per completed request that changed `core/ hooks/ scripts/ adapters/ plugins/`; docs-only = commit + push. Earlier only when the next ticket needs the hook or script just shipped.
- External member: `--detach`, next task, one `--collect` (it waits).
- After a dispatch: next unblocked task, never idle on a reviewer.
- Worktree only for a parallel task owner; Lead self-do (R1/R2) stays on main.
- R3 (multi-file) dispatches the task owner the plan names (hooks/scripts → devops-sre, python lib → backend-developer, docs → content-strategist); the Lead plans, spot-checks, commits.
- Docs task (R1 at any size): ≤ ~5 edit sites with the exact strings already in the plan → `Owner: Lead`; more sites, free prose or repo-wide docs → content-strategist (cheap tier), tracks in parallel, Lead spot-check. Payload doctrine (`core/skills`, `core/fragments`, hook messages) → the contract carries the canonical sentences; expect one fix round.
- Edits go through the CLI's edit tools, never a shell heredoc or sed: the edit-time hooks (self-do nudge, write scope, edit ledger, test-edit count) see tool edits only.
