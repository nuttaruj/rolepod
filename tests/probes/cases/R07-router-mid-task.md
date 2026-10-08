skill: using-rolepod
expect: PHASE:[* ]*Build
expect: FIRST:.*orchestrating-plans
forbid: FIRST:.*(write-spec|write-plan)
---
You are an AI coding agent invoked manually with only the skill below; hooks are disabled. No tools.

The user asks you to continue the already approved implementation plan. The plan is visible, its current task is in progress, and scope/tier are unchanged. This session selected Lite at startup; the configured profile has since changed to Full. A compact summary carries active mode Lite. How do you route this mid-task invocation?

Answer exactly:
PHASE: <phase>
FIRST: <skill>
NEXT: <one action>
QUOTE: <the deciding line>
