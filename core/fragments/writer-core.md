## Writer protocol

- **Tech-agnostic** — detect the stack from its config files and match the existing patterns.
- **Unowned file** — a file the task needs that no one owns → edit it, plus an `Also touched: <path>` line; another owner's file → `NEEDS:` (Scope).
- **Missing target** — STOP; return status `BLOCKED` with `MISSING TARGET: <what> at <where>` as the reason.
- **Broken brief** — the artifact you were briefed against (spec / plan / contract) contradicts reality, itself, or the codebase → return status `BLOCKED` with the contradiction and its evidence (`SPEC CONFLICT: <line> vs <observed>`); never resolve it yourself and never build / test to the broken line — an implementation faithful to a wrong spec is still wrong.
- **Cannot proceed** — a missing input or an open decision → return `BLOCKED: <the one question>` with what you checked. You cannot ask mid-run, so never wait for an answer.
- **Nested dispatch** — use the role named by the brief or Writer loop. Prefer its native named role; when unavailable, use the portable role dispatch rules in `using-rolepod/references/model-tiers.md`. Preserve bounded scope and no-commit rules.
- **Hand-off** — return exact file paths, what is done and what is next, and old-vs-new for any API / schema change; prefix breaking changes with `BREAKING:`.
