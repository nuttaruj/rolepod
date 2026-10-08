skill: write-plan
expect: ^EXACT-LIST: ARTIFACT=none \(inline checklist\); FORMAT=INLINE-CHECKLIST; OWNER-BRIEF=APPROVED-CHANGE-LIST[[:space:]]*$
expect: ^R2: ARTIFACT=none \(inline checklist\); FORMAT=INLINE-CHECKLIST; LINES=3-5; VERIFY=PER-LINE[[:space:]]*$
expect: ^ELIGIBLE-R3: ARTIFACT=none \(inline checklist\); FORMAT=INLINE-CHECKLIST; APPROVED-SPEC-SUPPLIES=FILES-ORDER-DEPENDENCIES-VERIFY-COMMANDS[[:space:]]*$
expect: ^PARALLEL-OR-HIGH-RISK: ARTIFACT=DATED-PLAN; PATH=docs/rolepod/plans/; REQUIRED=(TASK-LABELS|ALL-13-IN-ORDER)[[:space:]]*$
expect: ^REQUIRED-LABELS: ALL-13-IN-ORDER[[:space:]]*$
expect: ^LABEL-LIST: Delivers, Blocked by, Track, Files, Read first, Change, Test / evidence, Proof, Expected failing signal, Command, Owner, Done when, On fail\.?[[:space:]]*$
forbid: ^R2: ARTIFACT=SAVED-PLAN
forbid: ^PARALLEL-OR-HIGH-RISK: FORMAT=INLINE-CHECKLIST
---
You are an AI coding agent with only the standalone skill below; no other skill, reference, file or tool is available. Answer exactly in this format and quote the deciding sentence verbatim from the skill.

Situation variants:
1. The user approved an exact change list of at most three ordered, low-risk tasks; it names every target, verify command, dependency, and one owner.
2. One clear R2 task has one source file and a test.
3. An approved spec has three ordered, low-risk tasks whose files, dependencies, and Commands map one-to-one to one owner.
4. A six-task plan needs two parallel owners and one auth task.

For each variant, name the artifact path or write `none (inline checklist)`. EXACT-LIST must state that the approved change list is already the owner brief. R2 must state the checklist has 3–5 lines. For eligible R3, state explicitly that the approved spec already provides files, order, dependencies, and verify commands; these required details remain available to the owner through that spec and inline checklist. Do not call the inline checklist a saved plan.
Output the four scenario lines first. Then output both `REQUIRED-LABELS` and `LABEL-LIST` on their own lines; these two lines are mandatory and must not be omitted.

EXACT-LIST: ARTIFACT=<NONE|path>; FORMAT=<INLINE-CHECKLIST|SAVED-PLAN>; OWNER-BRIEF=<APPROVED-CHANGE-LIST|OTHER>
R2: ARTIFACT=<NONE|path>; FORMAT=<INLINE-CHECKLIST|SAVED-PLAN>; LINES=<3-5|OTHER>; VERIFY=<PER-LINE|OTHER>
ELIGIBLE-R3: ARTIFACT=<NONE|path>; FORMAT=<INLINE-CHECKLIST|SAVED-PLAN>; APPROVED-SPEC-SUPPLIES=<FILES-ORDER-DEPENDENCIES-VERIFY-COMMANDS|OTHER>
PARALLEL-OR-HIGH-RISK: ARTIFACT=<DATED-PLAN|NONE>; PATH=<docs/rolepod/plans/|OTHER>; REQUIRED=<TASK-LABELS|OTHER>
REQUIRED-LABELS: ALL-13-IN-ORDER|OTHER
LABEL-LIST: Delivers, Blocked by, Track, Files, Read first, Change, Test / evidence, Proof, Expected failing signal, Command, Owner, Done when, On fail.
QUOTE: <verbatim deciding sentence>
TRACE: <cite the relevant numbered section or exact rule>
