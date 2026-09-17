<!-- rolepod: in-repo AGENTS.md kept as a thin stub.

Rolepod's Codex always-on core installs as the managed block in
~/.codex/AGENTS.md — install.sh writes it from build/rendered/codex/AGENTS.md,
a build artifact rendered from adapters/codex/AGENTS.md.tmpl + core/fragments/
by build/render.sh.

Codex also auto-loads a repo-root AGENTS.md (project scope). A full core
here would load on top of the ~/.codex/AGENTS.md block — the same block
twice on every Codex session in this repo. This stub avoids that, matching
the in-repo CLAUDE.md stub.

Install rolepod globally (./install.sh --target=codex) to dogfood the gates
while working here; run `make render` to refresh the build artifact.
-->

# Working in this repo: gate cadence

Measured 2026-09-17: 198 full static-gate runs in two days, 127 of them on an
already-green tree. Run the check that covers the edit, the gate once.

- While editing: the ONE check that covers the file. Byte caps and surface
  invariants: `make test-lean-surface`. A hook: `bash -n hooks/<x>.sh` plus
  its case in `tests/integration/cases/`. A static check: `bash tests/static/<x>.sh`.
  Never the whole gate per edit.
- At commit: `make render && git add -A && make test-static` once, read the
  exit code (never pipe a gate through grep), then commit. Every commit still
  passes the full static gate; that floor is unchanged.
- At release: `make test-all` once, then the chain in `docs/release-checklist.md`.
- Release cadence: ONE release per completed request that changed shipped
  payload (`core/`, `hooks/`, `scripts/`, `adapters/`, `plugins/`), never per
  commit. Docs-only work is commit + push. Exception: the next ticket in this
  session needs the hook or script just shipped, so release and sync now.
- External members: `--detach`, take the next task, ONE `--collect` when you
  are back (it waits). No polling loop.
- After a dispatch: build the next unblocked task; never idle on a reviewer.
- A worktree only for a parallel task owner; Lead self-do (R1/R2) stays on main.
