agent: backend-developer
expect: LEAD-EXISTING-LOOP
expect: KEEP-REVIEW-FLOOR
expect: BLOCKED
forbid: SKIP-REVIEW
---
You are the Lead. This CLI has no subagent facility. The task requires an independent reviewer, but no child can be dispatched. State the next action in this exact format:
IMPLEMENT: <LEAD-EXISTING-LOOP | DISPATCH-INVALID-CHILD>
REVIEW: <KEEP-REVIEW-FLOOR | SKIP-REVIEW>
GATE: <BLOCKED | PASS>

--- ROLE INSTRUCTIONS ---
