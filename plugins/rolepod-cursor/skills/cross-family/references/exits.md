<!-- Load when the runner returns a non-zero exit. SKILL.md step 4 reads the receipt; step 5 names each caller's fallback. -->

# Runner exits

`cross-family.sh --help` prints the same list (`Exit:` line).

| Exit | Means | Next move |
|---|---|---|
| 0 | ok — the receipt is the last stdout line | step 4 reads it |
| 2 | usage — a bad flag, value or combination | fix the command; never a fallback |
| 3 | every member failed | step 5's fallback |
| 4 | the pool is on, nothing usable | step 5's fallback |
| 5 | the pool is off | step 5's fallback (step 1: say so and offer step 6 once when the user asked for another CLI) |
| 6 | a detached job is still running | `--collect` again later, or the caller's internal path |
| 7 | partial slice refused (`--cached` while the same files carry unstaged edits) | attach the full diff |
| 8 | a review job is live in the same slot | `--collect` or `--kill` it first |
| 9 | the `--member` CLI is not usable (not in the pool, not installed, or the Lead) | step 3's named-CLI rule |

- `--member` given: exit 9 or exit 3 → step 3's named-CLI rule (tell the user what is usable, ask before running the first one), never step 5's fallback unasked.
- A member dies when it goes silent (`stall=`, default 600 s), not when it is slow.
- A foreground call is capped by the harness (Claude Bash: 600 s): run a long review with `--detach`.
