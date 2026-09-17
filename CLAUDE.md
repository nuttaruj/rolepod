<!-- rolepod: in-repo CLAUDE.md kept as a thin stub.

Rolepod's Claude always-on core is delivered by the plugin's SessionStart
hook — hooks/always-on-loader.sh emits hooks/always-on-core.md as
additionalContext. install.sh registers the plugin; it writes no managed
block into ~/.claude/CLAUDE.md (rolepod no longer manages one).

hooks/always-on-core.md is a build artifact, rendered from
hooks/always-on-core.md.tmpl + core/fragments/ by build/render.sh.

A full gate block here would load on top of the hook-injected copy — the
same block twice on every session in this repo. This stub avoids that.
Install rolepod globally to dogfood the gates while working here; run
`make render` to refresh the build artifacts.
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
