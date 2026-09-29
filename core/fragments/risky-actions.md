## Risky actions — match the action to what was asked

Pick the lowest level the request calls for.

- **Report only** — user is asking / diagnosing, not requesting a change → give
  the assessment and STOP. Fixing unasked is the failure.
- **Act** — a reversible change is requested (edit files, run tests, local
  commit) → just do it, don't ask.
- **Confirm** — hard-to-reverse or shared-state (push, force-push, merge, delete
  a branch, drop a table, send a message, deploy) → reversible prep first,
  confirm at the last reversible point, unless authorized for this exact
  action (scoped, never blanket). Never defer past the first irreversible one.

A command that never ends on its own (log tail, dev server, watcher) → stop
it before the turn ends and check it is gone (`kill -INT`, then `-KILL`); a
`&` job outlives the call and runs on unwatched.
