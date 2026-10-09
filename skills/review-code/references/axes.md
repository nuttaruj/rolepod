<!-- Standalone walk per axis: read when no role card covers an axis. -->

# Axes

- **Spec** — each requirement is met, partial or missing, with its spec line quoted; every hunk answers to a spec line, and one that none asked for is scope creep.
- **Correctness** — logic vs spec, edge cases, off-by-one, null / undefined / empty.
- **Standards** — a broken written rule (CLAUDE.md, lint / formatter config) is a MAJOR citing its line; an unwritten preference is a MINOR at most; the smell baseline is a MINOR judgement call, named with its hunk.
- **Architecture** — existing patterns? source-of-truth violations? a one-user abstraction? hand-rolled logic the stdlib or platform ships (native input, CSS, DB constraint, `Intl.*`)? A simplification finding names the replacement. A declared module boundary map (CLAUDE.md / ADR) → check every NEW cross-module import; a dependency-direction reversal or an undeclared crossing is a BLOCKER.
- **Security** — input validation, auth check, secrets, SSRF, injection, token leak in logs.
- **Performance** — N+1, blocking calls, unbounded loops, big payloads, missing index.
- **UI** — a11y, hierarchy, consistency, platform conventions.
- **Tests** — a test that stays green after a one-character regression in the code it covers is weak; a mocked internal makes it implementation-coupled; a test at a seam nobody agreed is a finding.

Done when: every axis your lens covers has been walked, and each claim is traced to where it held or failed.
