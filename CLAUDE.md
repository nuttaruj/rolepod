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
