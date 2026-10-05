<!-- Load at review step 2 for the walk per axis. -->

# Axes

- **Depth** — Full R4: `security-engineer` and the adversarial pass trace in full; Lite and Standard use their intensity-specific reviewer sets (`review-code` step 2, Pick reviewers).
  A lens at any tier: a file the task changed is read from the diff; open it only when a hunk you must judge is cut off. Callers and other unchanged files may be opened. Skip what tooling enforces (lint, formatter, typecheck, the commit gate). Never re-run the suite (check-work runs it once; the finish-work pre-merge gate verifies this). A finding that needs a run: a reviewer with a shell runs only the diff's repro command; one without names it under Questions, and the task owner (else the Lead) runs it.
- **Intent** — first: the goal in one sentence; a smaller way, or should the change exist at all?
- **Trace** — the diff is the entry, not the scope: walk each claimed behavior (entry → call sites → branches → state → exit) through the seams into unchanged code; a surprise is a finding signal. Untouched code past the claims and seams is a Question, not a BLOCKER. Code-intel callers / impact when connected.
- **Correctness** — logic vs spec, edge cases, off-by-one, null / undefined / empty.
- **Security** — input validation, auth check, secrets, SSRF, injection, token leak in logs.
- **Performance** — N+1, blocking calls, unbounded loops, big payloads, missing index.
- **Architecture** — existing patterns? source-of-truth violations? a one-user abstraction? hand-rolled logic the stdlib or platform ships (native input, CSS, DB constraint, `Intl.*`)? A simplification finding names the replacement. A declared module boundary map (CLAUDE.md / ADR) → check every NEW cross-module import; a dependency-direction reversal or undeclared crossing is a BLOCKER.
- **Conventions** — a broken written rule (CLAUDE.md, lint / formatter config) = a MAJOR citing its line; an unwritten preference = a MINOR at most.
- **UI** — a11y, hierarchy, consistency, platform conventions.
- **Tests** — assertion strength, mocks at the right boundary, races for concurrent code. *Modifying an existing test* on the way to green is a finding until justified (loosened assertion, raised tolerance, deleted case, skip / only, absorbed snapshot). N call-site tests of one shared rule → one at the owner + at most one smoke per call site with wiring of its own. A new test naming a calendar date or the real clock → derive from one frozen now.

Done when: every axis the depth rule requires has run and each claim is traced to where it held or failed.
