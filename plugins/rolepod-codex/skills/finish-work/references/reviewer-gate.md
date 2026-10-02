<!-- Load when the Reviewer pre-merge gate runs on a high-risk diff. -->

# Reviewer gate — reading the Cross-model line

On a high-risk diff, check the review reports against the review mode (from `review-code`'s Review mode):

**In `standard` mode:** the `security-engineer` report must be present; an adversarial pass is not run.

**In `full` mode:** read the review report's **Cross-model adversarial pass** line before merge:

- `ran on <cli>` (a ROLEPOD-XFAM ok receipt) clears the gate whatever the family field says. A CLI preset that reports no model family is stated neutrally, never as a limitation.
- `NOT RUN — cross-family off (opt-in)` / `NOT RUN — wide-effort session` is the user's choice: one neutral line in the finish menu.
- `NOT RUN` for any other reason (pool failed / empty, the internal strong pass ran instead) or `vertical — same CLI` is a limitation the user sees before merge; the gate still passes.
- Missing `security-engineer` report or missing adversarial pass — the Lead's own walk in its place — blocks the merge; only the user's waiver naming this gate, quoted in the finish menu, clears it. Never clear the gate silently.
- A missing lens report (`<task>-spec.md` / `<task>-standards.md`) is one limitation line the user sees before merge, never a block.
