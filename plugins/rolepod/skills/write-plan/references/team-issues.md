# Team issues — publish plan tasks to the repo tracker

Optional backend for the approved plan when **more than one person or machine
will build it**. Solo work skips this entirely: the plan file already carries
order, tests, and checkboxes, and adding a tracker for one builder is pure
overhead. Turn this on only when the user says the work is shared. The plan
lives in `docs/rolepod/`, which is private by default (gitignored, gate-denied)
— before publishing, either track it (`.rolepod/docs-tracked`) or accept that
the issue bodies are the only artifact a teammate on another machine can read.

The plan file stays the **canonical contract**. Issues are the coordination
layer on top: an index of who-takes-what, never a second copy of the plan.
Gist + link, don't duplicate task bodies.

## The mapping

| Plan concept | Tracker form |
|---|---|
| One task (or spec slice) | One GitHub issue — title = task title; body = what it delivers + acceptance criteria + link to the plan file at its commit |
| Task order / dependency | Native issue dependency (`blocked_by`); fallback: a `Blocked by: #n` line at the top of the body |
| Who is on it | Assignee. **Assignee = claim.** An open, unblocked, unassigned issue is takeable; assigning yourself is the first write, before any code |
| What can start now | The **frontier**: open + unblocked + unassigned |
| Task done | Close the issue with a comment pointing at the commit / PR — and flip the plan checkboxes too; the plan stays canonical |

## Publishing (after plan approval only)

Creating issues on a shared repo is outward-facing — **confirm with the user
before publishing**, and show the issue list you are about to create.

1. Create issues in dependency order (blockers first — they need ids before
   dependents can reference them):
   `gh issue create --title "..." --body "$(cat <<'EOF' ... EOF)"`
2. Second pass, wire the edges. Native dependencies use the blocker's numeric
   **database id** (`gh api repos/<o>/<r>/issues/<n> --jq .id` — not the `#n`):
   `gh api --method POST repos/<o>/<r>/issues/<child>/dependencies/blocked_by -F issue_id=<db-id>`
   Repo has no dependency support → write the `Blocked by: #n` line instead.
3. Add a `ready` label so takeable work is filterable in the tracker UI.
4. Note in the plan file header that the issues backend is on, with the issue
   numbers per task — the builder's session reads the plan first.

## Working a shared plan (implement-plan side)

- **Claim before work**: `gh issue edit <n> --add-assignee @me` — first write
  of the session. Someone else already assigned → pick the next frontier issue.
- Blocked mid-task → comment the blocker on the issue so the team sees it
  without opening your session.
- Done = Command passes + review clean → close with the commit / PR pointer.
- Expect concurrent editors: re-check assignee state before claiming, and never
  edit another claimer's issue body.

## Decision maps ride the same backend

A `chart-work` map that the team shares uses the identical shape: map = parent
issue, each `q-<slug>` ticket = child issue, same claim rule, close on Decided.
Local `docs/rolepod/maps/` stays the solo default there too.
