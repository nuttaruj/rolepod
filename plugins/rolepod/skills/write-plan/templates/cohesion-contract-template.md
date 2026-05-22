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
