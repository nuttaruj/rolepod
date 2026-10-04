<!-- Load when the Reviewer pre-merge gate runs on a high-risk diff. -->

# Reviewer gate — reading the Cross-model line

On a high-risk diff, use the active session mode carried from startup/manual selection, then check the matching reports. Do not re-read configured mode at Ship; configuration changes apply after restart or a new session. Configured-mode inspection is separate. `review-mode.sh` is only a compatibility review-intensity helper.

**In `lite` mode:** both isolated `universal-reviewer` lens reports (`spec` and `standards`) must cover the same immutable H1 snapshot. With agents available, a missing, failed, empty, or partial report keeps that same round open; that same isolated reviewer completes it against H1. Only when agents are unavailable does the Lead perform both axes and record the lack of reviewer independence as a limitation. No security or adversarial report is required.

Fixed findings follow `review-code` Fix-verify: each source report stays at H1, the receipt records each closure with the H1→H2 delta and verified H2, and the re-check has its own report at H2. Existing valid merged reports remain readable. Reuse H1 reports only when `check-work` verifies H2, the current tree is clean at H2, and every H1→H2 change is a verified finding fix. Unrelated/new changes are uncovered and must be surfaced and routed at their current tier and mode; never relabel H1 as H2.

**In `standard` mode:** R4 requires the `security-engineer` report and both lens reports; an adversarial pass is not run or recorded. For a comment/blank-only R4 diff, apply the `review-code` exception.

**In `full` mode:** Full R4 requires the adversarial pass and its evidence, except for the comment/blank-only R4 case handled by `review-code`; read the review report's **Cross-model adversarial pass** line before merge. If an external pass is unavailable or intentionally not used, the required internal strong pass must be recorded; `NOT RUN` alone does not satisfy the Full R4 floor:

- `ran on <cli>` (a ROLEPOD-XFAM ok receipt) clears the gate whatever the family field says. A CLI preset that reports no model family is stated neutrally, never as a limitation.
- `NOT RUN — cross-family off (opt-in)` / `NOT RUN — wide-effort session` describes the user's choice of external reviewer; it does not replace required Full R4 adversarial evidence.
- `internal strong pass — <reason>` records the required internal pass when external review is unavailable or intentionally not used. `NOT RUN` with no completed internal pass, or `vertical — same CLI` without an accepted pass, is a limitation and does not satisfy the Full R4 floor.
- Missing required `security-engineer`, lens, or Full R4 adversarial report keeps the same review round open; the same isolated reviewer completes its report on the frozen H1. Never substitute a Lead review when agents are available. Only a user waiver naming the gate, quoted in the finish menu, clears a report requirement; never clear it silently.
