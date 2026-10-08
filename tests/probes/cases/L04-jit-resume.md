skill: manage-context
expect: ^COMPACTED: ACTION=RESUME; REANCHOR=GIT-STATUS-RECENT-COMMITS; PHASE=ORIGINAL[[:space:]]*$
expect: ^EXPLICIT-LEGACY: HANDOFF=EXACT-DATED-PATH; SUBSTITUTE-NEWER-DEFAULT=NO[[:space:]]*$
expect: ^MISSING-OR-WRONG-CHECKOUT: ACTION=STOP; ASK=YES[[:space:]]*$
expect: ^INLINE-STATE: RESTORE=CHECKLIST-FROM-HANDOFF-OR-ARTIFACT; READ=ONLY-REQUIRED-DETAILS[[:space:]]*$
expect: ^DEBUG: SECOND-OPINION=BEFORE-FIX-3[[:space:]]*$
expect: ^MODE: SAME-SESSION=ACTIVE-MODE-PERSISTS; FRESH-SESSION=NEWLY-CAPTURED-PROFILE[[:space:]]*$
forbid: ^EXPLICIT-LEGACY: SUBSTITUTE=NEWEST-FILE
forbid: ^MISSING-OR-WRONG-CHECKOUT: ACTION=CONTINUE-EDITING
---
You are an AI coding agent with only the standalone skill below; no other skill, reference, file or tool is available. Use no tools; answer from the text. Answer exactly in this format and quote a deciding sentence verbatim from the skill.

Situation variants:
1. You compacted mid-plan. The summary carries the active task, mode, and inline checklist; `git status` confirms the checkout.
2. The user names a dated legacy handoff path, although a newer default handoff exists.
3. The requested handoff is missing or belongs to another checkout.
4. The summary points to a receipt and one predecessor contract, but not to the full plan; a decision is missing from both.
5. The same repro has failed twice.
6. Later in this same session, the configured mode changes; then a genuinely fresh session starts.

Use each label exactly. State whether to resume or stop and what to read. For DEBUG, state when the second opinion is required. For MODE, state that configuration changes do not change active mode in the same session, while a fresh session uses the newly captured profile.

COMPACTED: ACTION=<RESUME|STOP>; REANCHOR=<GIT-STATUS-RECENT-COMMITS|OTHER>; PHASE=<ORIGINAL|OTHER>
EXPLICIT-LEGACY: HANDOFF=<EXACT-DATED-PATH|OTHER>; SUBSTITUTE-NEWER-DEFAULT=<NO|YES>
MISSING-OR-WRONG-CHECKOUT: ACTION=<STOP|CONTINUE>; ASK=<YES|NO>
INLINE-STATE: RESTORE=<CHECKLIST-FROM-HANDOFF-OR-ARTIFACT|OTHER>; READ=<ONLY-REQUIRED-DETAILS|ALL-ARTIFACTS>
DEBUG: SECOND-OPINION=<BEFORE-FIX-3|OTHER>
MODE: SAME-SESSION=<ACTIVE-MODE-PERSISTS|OTHER>; FRESH-SESSION=<NEWLY-CAPTURED-PROFILE|OTHER>
QUOTE: <verbatim deciding sentence>
TRACE: <cite the relevant numbered section or exact rule>
