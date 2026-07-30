<!-- Rolepod cohesion contract — pin this BEFORE any parallel agent starts. -->
<!-- Required whenever more than one agent edits code on the same feature. -->

# <Feature> Cohesion Contract

## Shared goal
<One sentence — what all agents are jointly building.>

## Owners
<Each agent + the slice it owns.>
- `<agent>` — <slice>

## File ownership
<Exact paths each agent may edit. No path appears under two owners.>
- `<agent>`: `path/a`, `path/b`

## Shared interfaces
<Function signatures, API shapes, types crossed between owners. Frozen —
 a change here needs every owner to agree.>

## Merge order
<Which slice merges first, and why. Usually the interface provider.>

## Do-not-touch list
<Files no agent edits this round — stable surfaces, other teams' code.>

## Verification per agent
<What each owner must prove green before handing the slice back.>

## Integration owner
<The single agent (usually Lead) who merges the slices and runs the
 whole-feature verification.>

## Session split (optional — separate CLI sessions as track owners)
<Fill ONLY when tracks run as separate CLI sessions instead of subagents —
 e.g. an API-heavy track on codex, a UI-heavy track on claude. Assign each
 track a session/CLI by strength (the user's call), a branch (or worktree),
 and name the one integration session. Delete this section otherwise.>
- Track <A>: <CLI / session> — branch `<feature>/track-a`
- Track <B>: <CLI / session> — branch `<feature>/track-b`
- Integration session: <which session merges, in Merge order above>

Kickoff prompt per session — paste verbatim, fill the track:
> You own track <X> of <feature> per the cohesion contract at `<path>`.
> Execute ONLY your track's tasks from the plan at `<path>`. Edit only your
> owned files; shared interfaces are frozen — a needed change stops for
> renegotiation in the contract file, never a silent edit. Flip only your
> own tasks' checkboxes. Commit to your track branch; the integration
> session merges in contract order.
