<!-- Thin stub: the Codex core is the managed block in ~/.codex/AGENTS.md (install.sh --target=codex, rendered from adapters/codex/AGENTS.md.tmpl). A full block here would load twice. -->

# Gate cadence

- Editing: only the check that covers the file — `make test-lean-surface` (caps, invariants), `bash tests/static/<x>.sh`, `bash -n hooks/<x>.sh` + its case in `tests/integration/cases/`.
- Commit: `make render && git add -A && make test-static` once; read the exit code, never `| grep`.
- Release: `make test-all` once, then `docs/release-checklist.md`.
- One release per completed request that changed `core/ hooks/ scripts/ adapters/ plugins/`; docs-only = commit + push. Earlier only when the next ticket needs the hook or script just shipped.
- External member: `--detach`, next task, one `--collect` (it waits).
- After a dispatch: next unblocked task, never idle on a reviewer.
- Worktree only for a parallel task owner; Lead self-do stays on main.
