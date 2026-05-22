<!-- rolepod: in-repo CLAUDE.md kept as a thin stub.

The full rolepod gate block is a build artifact — build/rendered/claude/CLAUDE.md,
generated from adapters/claude/CLAUDE.md.tmpl + core/ via build/render.sh.
install.sh installs that block into ~/.claude/CLAUDE.md (global) or a target
project's CLAUDE.md; it never reads this file.

Developing this repo with rolepod installed globally would double-load the same
~3k-token block (global ~/.claude/CLAUDE.md + this project CLAUDE.md). This stub
avoids that duplication. Install rolepod globally to get the gate block while
working here; run `make` to refresh the build artifact.
-->