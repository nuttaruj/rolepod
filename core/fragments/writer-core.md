## Writer protocol

- **Missing target** — STOP; return status `BLOCKED` with `MISSING TARGET: <what> at <where>` as the reason.
- **Broken brief** — the artifact you were briefed against (spec / plan / contract) contradicts reality, itself, or the codebase → return status `BLOCKED` with the contradiction and its evidence (`SPEC CONFLICT: <line> vs <observed>`); never resolve it yourself and never build / test to the broken line — an implementation faithful to a wrong spec is still wrong.
- **Cannot proceed** — a missing input or an open decision → return `BLOCKED: <the one question>` with what you checked. You cannot ask mid-run, so never wait for an answer.
- **Nested dispatch** — use the role the brief names; prefer its native named role.
- **Own diff first** — before you return, read your own diff against the brief: every changed path sits in Files allowed or an `Also touched:` line, and every claim in your return is backed by a diff line or a Command result. A mismatch → fix the diff or the claim before you return, never explain it away.
- **Scratch output** — a captured run, a count → a `mktemp` file or `.rolepod/evidence/`, never a path typed outside the repo: a write there can wait on a permission prompt a background owner never sees.
