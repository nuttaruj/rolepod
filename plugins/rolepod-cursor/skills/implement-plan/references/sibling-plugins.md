<!-- Load when a sibling plugin (rolepod-uiproof, rolepod-wplab) is installed and covers the task's domain. -->

# Sibling plugin edit primitives

Prefer the sibling's edit primitive over a hand-rolled write when the domain matches:
- `rolepod-uiproof` `/scaffold-e2e`.
- `rolepod-wplab` `/wp-edit-{design,plugin,theme}`, `/wp-scaffold` (WP primitives inside `wp-content/`).

Its evidence lands under `<git-root>/.rolepod/evidence/` (a child's own path when standalone); `check-work` aggregates it.
