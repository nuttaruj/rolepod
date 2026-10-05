<!-- Load when the cross-family pool is enabled, or on an internal-pass question. The adversarial pass (what counts, apex, strong class) is the `adversarial-review` skill. -->

# External review routing

An external review routes to a **different CLI** than the Lead's, never to the Lead's own; the model family is information, not a filter.

## When the external runs

- **The pool is the user's choice, and it is opt-in** (set `pool` in `~/.rolepod/config.json` machine-wide only; unset key or `pool.cross-family: "off"` = off). Never turn it on unasked.
- **Pool enabled:** external lenses run on R3 or R4 diffs (`review-code` Pick reviewers). A comment-only, config-only or rename-only diff and a wide-effort session stay internal. R2 diffs keep internal lenses. Money and auth require the active mode's R4 set (per `review-code`).
- **Full R4 adversarial pass:** external when pool is usable, else internal universal-reviewer `mode: adversarial` at strong class.
- An external lens comes back weak when its return is empty or PARTIAL, a changed file is missing from its Scope list, or it gives a bare verdict with no claim walked; its report is the raw file its `ROLEPOD-XFAM ok … raw=<path>` receipt names.
- **Fallback:** A lens whose run fails, comes back weak, or is refused → `universal-reviewer` with that lens, same round.

## Round 2+

The external runs round 1 only; round 2+ is the internal re-check in `review-code` Fix-verify.

## Fallback follows the active review contract

Fallback follows the active mode's contract. Lite may use the Lead's two-axis walkthrough with an independence limitation only when agents are unavailable. In Standard and Full, a missing, failed, empty, or partial required report keeps the same round open; the assigned reviewer completes it on H1. Never use a generic Lead floor to satisfy a required report. If dispatch is impossible or the user forbids agents, stop and record the limitation or waiver path required by `review-code` and `adversarial-review`.

Strength routing may assign a specialist to an axis when available; it never removes a required axis. A missing specialist does not make the Lead an independent reviewer.

Only Full R4 uses an adversarial pass and its Cross-model line, following the `adversarial-review` skill. Lite and Standard do not gain either from pool availability alone.

This never widens WHO reviews: an external lens runs only where `review-code` Pick reviewers puts a lens. It never adds adversarial review to Lite or Standard R4; an explicit user or caller request for cross-family review remains in force.
