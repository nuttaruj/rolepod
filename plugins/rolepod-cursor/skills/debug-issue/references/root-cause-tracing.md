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
5. **Stop at a legitimate boundary** — external input (user / API / env / DB
   row), a system boundary (network / OS / third-party), or an intentional
   invariant ("designed this way").

## Symptom fix vs root fix
- **Symptom fix** — patches where the value is *used* (a null-check, a clamp,
  a retry). The bad value is still produced; it resurfaces elsewhere.
- **Root fix** — corrects where the value is *produced*. The bad value never
  exists again.

A defensive `?.` or `try/catch` added without knowing the cause is a symptom
fix wearing a disguise. If you cannot name why the value is bad, you have not
finished tracing.

## When the trace forks
Two callers, two different bad values → there may be two bugs, or one shared
upstream cause. Trace each independently before concluding.
