skill: check-work
expect: CASE=VALID\s+ACTION=(CITE|NO-NEW-CHECK)\s+STATUS=VERIFIED\s+REASON=.*((scoped|scope).*(proof|receipt).*(match|remain|valid|cover|unchanged|same)|(proof|receipt).*(scoped|scope).*(match|remain|valid|cover|unchanged|same))
expect: CASE=UNTRACKED-CHANGED\s+ACTION=RERUN\s+STATUS=UNVERIFIED
expect: CASE=ZERO-TEST\s+ACTION=RUN\s+STATUS=UNVERIFIED
expect: CASE=PHASE-CHANGE\s+ACTION=NO-NEW-CHECK\s+STATUS=VERIFIED
expect: CASE=REQUIRED-GATE\s+ACTION=RUN\s+STATUS=UNVERIFIED
forbid: CASE=VALID\s+ACTION=FULL-SUITE
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Classify each situation using only the skill. Keep each answer to one line, exactly in this format:
CASE=<id> ACTION=<CITE | RERUN | NO-NEW-CHECK | RUN> STATUS=<VERIFIED | UNVERIFIED> REASON=<brief evidence>

CASE=VALID: The owner ran the planned scoped Command after the final relevant edit. Its passing output covers the changed behavior and affected consumer. The receipt records command, result, execution snapshot, environment and provenance. Relevant tracked, untracked and ignored inputs are unchanged, and the environment and provenance still match. Verify begins as a new phase; the task has no uncovered criterion or required gate left.

CASE=UNTRACKED-CHANGED: The same passing command and receipt exist, but an ignored fixture read by the command changed after that run. No later run covers that input.

CASE=ZERO-TEST: A cited test command exits zero but reports 0 tests collected. No other proof covers its acceptance criterion.

CASE=PHASE-CHANGE: A task's valid scoped passing proof still covers its claims when it moves from Build to Verify. Nothing relevant changed and no required check is uncovered.

CASE=REQUIRED-GATE: A valid scoped proof covers code behavior, but the change is high-risk and its required CI lane and post-deploy smoke have not run.

Do not infer that prompt text or a dry-run proves model behavior. Classify evidence only from the stated execution results.
