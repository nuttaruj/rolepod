<!-- Rolepod PR body template. Fill, then pass to `gh pr create` via HEREDOC. Delete <hints>. -->

## Summary
<1-3 bullets — what changed and why. The "why", not a file list.>
- <change>
- Scope: <what this PR leaves out>

## Test plan
<A checklist a reviewer can run to confirm the change; for the run that proves it, before → after.>
- [ ] <test / command / manual step> — before: <result> → after: <result>

## Risks
<What could go wrong, the blast radius, the rollback. Door: one-way (a revert does not undo it) / two-way.
 "Low — <reason>" is valid if true.>

## Linked artifacts
<`docs-mode.sh status` = `tracked` → link the spec / plan; else summarize. High-risk surfaces touched.>
