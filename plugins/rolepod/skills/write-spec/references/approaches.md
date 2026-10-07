<!-- Load from write-spec Approaches when the architect trigger or the ADR tests fire. -->

# Approaches — architect dispatch and ADRs

## Architect dispatch

When the trigger fires, ONE `rolepod-builder` dispatch with `domain: architecture`, on a strong-class model (API / data-model / integration design) drafts the three lenses (minimal / clean / pragmatic) and returns them inline, no receipt; its brief names the absolute path of `references/approaches.md`.
- A public API change with no backward-compatible path → stop and ask before any build.
- Parallel builders on one design → the cohesion contract comes before the first build.
- Brief: the request, the answers so far, the three lens names, and the approval gate the user expects.
- The Lead judges the draft and presents it; the user still decides at Gate 1.
- Anything else, or no subagents → the Lead drafts the lenses.

## ADR

Write an ADR only when all three hold:
1. hard to reverse;
2. surprising without context;
3. a real trade-off between genuine alternatives.

Any one missing → the spec is the record.

Save to `docs/adr/NNNN-<slug>.md` — context, decision, consequences, one page. `rolepod-builder` with `domain: writing` (`audience: dev`) may write it, and any other durable spec artifact.
