<!-- Load when the Reviewer pre-merge gate runs on a high-risk diff. -->

# Reviewer gate — reading the Cross-model line

On a high-risk diff, use the active session mode carried from startup/manual selection, then check the matching reports. Do not re-read configured mode at Ship; configuration changes apply after restart or a new session. Configured-mode inspection is separate. `review-mode.sh` is only a compatibility review-intensity helper.

**In `lite` mode:** both isolated `universal-reviewer` lens reports (`spec` and `standards`) must cover the same immutable H1 snapshot; when agents are unavailable, the Lead performs both axes and records the lack of reviewer independence as a limitation. No security or adversarial report is required.

For a no-recheck fix, the merged report keeps H1 unchanged and records finding-specific author repro/test evidence, the exact bounded H1→H2 delta, and final verified snapshot H2. Reuse H1 reports only when `check-work` verifies H2, the current tree is clean at H2, and every H1→H2 change is a verified finding fix. A green suite alone is insufficient. Unrelated/new changes are uncovered and must be surfaced and routed at their current tier and mode; never relabel H1 as H2.

Full R4 re-checks only code-touching fixes for findings raised by `security-engineer` or the adversarial pass. A required re-check gets its own report at H2; it never mutates or relabels the original H1 reports.

**In `standard` mode:** the `security-engineer` report must be present; an adversarial pass is not run.

**In `full` mode:** read the review report's **Cross-model adversarial pass** line before merge:

- `ran on <cli>` (a ROLEPOD-XFAM ok receipt) clears the gate whatever the family field says. A CLI preset that reports no model family is stated neutrally, never as a limitation.
- `NOT RUN — cross-family off (opt-in)` / `NOT RUN — wide-effort session` is the user's choice: one neutral line in the finish menu.
- `NOT RUN` for any other reason (pool failed / empty, the internal strong pass ran instead) or `vertical — same CLI` is a limitation the user sees before merge; the gate still passes.
- Missing `security-engineer` report or missing adversarial pass — the Lead's own walk in its place — blocks the merge; only the user's waiver naming this gate, quoted in the finish menu, clears it. Never clear the gate silently.
- A missing lens report (`<task>-spec.md` / `<task>-standards.md`) is one limitation line the user sees before merge, never a block.
