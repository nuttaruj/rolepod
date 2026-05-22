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
