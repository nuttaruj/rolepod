skill: using-rolepod
expect: ROUTE:[* ]*R2
expect: FIRST:[* ]*debug-issue
expect: REEVALUATE:[* ]*no
forbid: FIRST:.*write-spec
---
You are an AI coding agent with only the skill below; hooks are disabled. No tools. Answer from the skill.

The user says: "The pagination bug is still here; fix it." At this manual, no-hook session's first `using-rolepod` entry selected Lite, and that active profile is carried in context. Config now says Full. You already routed this same request earlier and ran a read-only `git status` tool call. Scope and tier are unchanged. Does that tool call or configured-mode change reroute the request? Route the concrete bug first.

Answer exactly:
ROUTE: <tier>
FIRST: <skill>
REEVALUATE: yes | no
QUOTE: <the deciding line>
