<!-- Load from write-spec Approaches when the architect trigger or the ADR tests fire. -->

# Approaches — architect dispatch and ADRs

## Architect dispatch

The approach adds or changes a DB table / migration, a public API contract, or a module boundary → ONE `system-architect` dispatch (API / data-model / integration design) drafts the three lenses (minimal / clean / pragmatic), returned inline — no file.
- Brief: the request, the answers so far, and the approval gate the user expects.
- The Lead judges the draft and presents it; the user still decides at Gate 1.
- Anything else, or no subagents → the Lead drafts the lenses.

## ADR

Write an ADR only when all three hold:
1. hard to reverse;
2. surprising without context;
3. a real trade-off between genuine alternatives.

Any one missing → the spec is the record.

Save to `docs/adr/NNNN-<slug>.md` — context, decision, consequences, one page. `content-strategist` (`audience: dev`) may write it, and any other durable spec artifact.
