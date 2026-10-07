Scope-splitting assumes you can list the shippable outcomes. Some requests
arrive a level above that: the goal is real, but between here and any
outcome sit open decisions — architecture picks, unknown constraints,
questions only the user can answer — and until they fall, no slice list is
honest. Charting plans the **decisions**, not the build: resolve them one at
a time until the slices become listable, then hand each slice to a normal
spec.

## The decision map

One markdown file per effort: `docs/rolepod/maps/<effort>.md`. Question
tickets live beside it in `docs/rolepod/maps/<effort>/q-<slug>.md`. Both
persist across sessions under `docs/rolepod/` (`write-spec` Gate 1); they enter git according to `docs-mode.sh status`.

```markdown
# Map: <effort>

## Target
<what "charted" means for this effort — the spec set, the locked decision,
 or the change itself. 1-2 lines; every session re-reads this first.>

## Ground rules
<standing constraints for the whole effort — the user's non-negotiables and
 doctrine that applies. A soft preference says so in its wording.>

## Decided
- [q-<slug>](./<effort>/q-<slug>.md) — <one-line gist of the resolution>
- <decision> — <why> (no ticket; a spec cites it as `Decided — <decision>`)

## Phases
<a spec set only: phase · outcome · depends on · build order · spec file>

## Still fuzzy
<questions you can feel coming but cannot phrase precisely yet — prose,
 as loose as honesty requires. Never pre-sliced into tickets.>

## Ruled out
- <gist> — <why it sits outside the target> (link the closed ticket if one existed)
```

The map is an **index, not a store**. A resolution lives in exactly one
place — its ticket, or its one Decided line when discovery settled it. The map gists a ticket in one line and links it.

## Question tickets

```markdown
Status: open | resolved | ruled-out
Blocked-by: q-<slug>, q-<slug>   # omit when unblocked
Kind: discuss | investigate | probe | unblock
Product mode: change | new       # probe only
Paths: <paths the question touches>   # probe in change mode only

## Question
<the single decision this ticket resolves — sized to one session>

## Resolution
<appended when resolved: the decision, the reason, pointers to evidence>
```

**Sharp or still fuzzy?** A question earns a ticket when it can be **stated
precisely now** — answerable or not. If it cannot be phrased that sharply,
it stays in *Still fuzzy*. Do not pre-slice the unknown into ticket-sized
pieces: one loose patch may become three tickets or zero once the decisions
ahead of it fall.

**Kinds**, mapped to standard rolepod machinery — charting adds no new
tools:

| Kind | Who | Resolve with |
|---|---|---|
| `discuss` | with user | Discovery (`write-spec` Discovery) on the one question. Default kind. |
| `investigate` | agent alone | Dispatch a `scout` — docs, APIs, prior art; report → resolution. |
| `probe` | with user | `write-prototype` on the question ticket. |
| `unblock` | either | Real work a decision is waiting on (provision access, move data so its shape is visible). The only kind that *does* instead of decides. Human-only steps → generate a wizard (implement-plan `references/wizard.md`). |

`discuss` and `probe` resolve **only through the user's own answers** — the
agent never fills in the user's side of the exchange.

## Working the map

Per session: **one decision** (`investigate` tickets exempt — fan them out in
parallel via scouts).

1. Re-read the map (not every ticket). Pick the first open, unblocked
   ticket — or the one the user names. An `investigate` ticket's Resolution
   predates now — if the touched code or dependency has since changed,
   re-run the scout before trusting it.
2. Resolve per its kind. Zoom into related resolved tickets only as needed.
3. Record: write `## Resolution` in the ticket (a `probe`: `write-prototype`
   already wrote it), flip `Status: resolved`,
   add the one-line gist to **Decided**. The user reversing a resolved
   decision appends a dated superseding `## Resolution` and edits the gist
   in place — it never reopens tickets that did not depend on the changed
   part.
4. Ripple: any *Still fuzzy* patch this resolution made phrasable becomes
   a ticket now (and leaves the ledger). Any ticket it invalidated is
   edited or closed. Anything it revealed as beyond the Target moves to
   **Ruled out** — closed, not resolved.
5. Save the map + ticket; both follow `docs-mode.sh status` for git tracking.

## Entry and exit

**Entry — chart only when charting is needed.** First map the ground with a
breadth-first discovery pass (fan wide, not deep). If that pass surfaces no
blocking decisions — the slices are already listable — stop charting: no tickets.
Route to scope-splitting.md or a single spec. A spec set still writes the
map, with only **Phases** and **Decided**; for one spec a map is ceremony.

**Exit — the map ends where specs begin.** The map is done when nothing is
left to decide: *Still fuzzy* is empty and every ticket is resolved or
ruled out. Then list the slices (they are now visible) as Phases, confirm the build
order with the user in Discovery, and write every slice's spec in one sitting — each spec citing the map's
**Decided** entries instead of re-litigating them. The urge to start
building mid-map is the signal a patch of the map is already clear enough
to hand off — hand that slice to write-spec; do not build from the map.
