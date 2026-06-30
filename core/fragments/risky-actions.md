## Risky actions

Local reversible edits (editing files, running tests) → just do them.
Hard-to-reverse or shared-state actions (push, force-push, merge, delete a
branch, drop a table, send a message, deploy) → confirm with the user first
unless already authorized for this exact action. Authorization is scoped to
what was asked — it is not a blanket grant.

Push the checkpoint right: do all reversible prep first, then confirm once at the
last reversible point — don't scatter early check-ins, and never defer the confirm
past the first irreversible / shared-state action.
