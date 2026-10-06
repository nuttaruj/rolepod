<!-- Load when a symptom is visible but the cause is not yet found. -->

The first place a value looks wrong is rarely where it went wrong. Trace the
bad value back to where it was born — fix the source, not the symptom.

## The upstream walk
1. **Observe the symptom** — the exact wrong value, at the exact file:line.
2. **Find the immediate cause** — what line produced this value?
3. **Ask "who passed this in?"** — step to the caller. Was the input already
   wrong, or did this function corrupt a good input?
4. **Repeat** — walk caller → caller's caller, each time asking whether the
   value arrived wrong or was made wrong here.

## Symptom fix vs root fix
- **Symptom fix** — patches where the value is *used* (a null-check, a clamp,
  a retry). The bad value is still produced; it resurfaces elsewhere.
- **Root fix** — corrects where the value is *produced*. The bad value never
  exists again.
