<!-- Load when the Reviewer pre-merge gate runs on a high-risk diff. -->

# Reviewer gate — reading the Cross-model line

On a high-risk diff, read the review report's **Cross-model adversarial pass** line before merge:

- `ran on <cli>` (a ROLEPOD-XFAM ok receipt) clears the gate whatever the family field says. A CLI preset that reports no model family is stated neutrally, never as a limitation.
- `NOT RUN — cross-family off (opt-in)` is the user's choice: one neutral line in the finish menu.
- `NOT RUN` for any other reason (pool failed / empty) or `vertical — same CLI` is a limitation the user sees before merge. Never clear the gate silently.
