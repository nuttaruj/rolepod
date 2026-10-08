skill: write-spec
expect: ^OBVIOUS: DEFINE=SKIP; NEXT=FIX; IMPLEMENT=NOW[[:space:]]*$
expect: ^AMBIGUOUS: DEFINE=RUN; NEXT=CLARIFY-ACTOR-TARGET-SUCCESS; IMPLEMENT=AFTER-GATE1[[:space:]]*$
expect: ^RISK: DEFINE=RUN; NEXT=SPECIFY-RISK-PLAN; PLAN=SECURITY-MIGRATION-AUDIT; IMPLEMENT=AFTER-GATE1[[:space:]]*$
forbid: ^OBVIOUS: DEFINE=RUN
forbid: ^AMBIGUOUS: IMPLEMENT=BEFORE-GATE1
forbid: ^RISK: DEFINE=SKIP
---
You are an AI coding agent with only the standalone skill below; no other skill, reference, file or tool is available. Answer exactly in this format and quote a deciding sentence verbatim from the skill.

Situation variants:
1. A one-line typo fix with an obvious diff and no risk surface.
2. A commission to "make team exports better" with no actor, target, or success criterion.
3. A request to change recovery-key rotation on a billing surface; desired behavior is unclear.

For each, say whether to skip or run Define, what the next action is, and whether implementation may start before the spec file is approved. The billing/recovery-key spec must include a security, migration, or audit plan; cite the high-risk rule that requires it.

Use these tagged enums: DEFINE=SKIP|RUN; IMPLEMENT=NOW|AFTER-GATE1; NEXT=FIX|CLARIFY-ACTOR-TARGET-SUCCESS|SPECIFY-RISK-PLAN; PLAN=SECURITY-MIGRATION-AUDIT.
OBVIOUS: DEFINE=<enum>; NEXT=<enum>; IMPLEMENT=<enum>
AMBIGUOUS: DEFINE=<enum>; NEXT=<enum>; IMPLEMENT=<enum>
RISK: DEFINE=<enum>; NEXT=<enum>; PLAN=<enum>; IMPLEMENT=<enum>
QUOTE: <verbatim deciding sentence>
TRACE: <cite the relevant numbered section or exact rule>
