---
name: cross-family
description: Use when a calling skill names a cross-family kind (review, critique, consult); the user asks another CLI for a second opinion or review of a diff, spec or bug; the user asks to set up or change the cross-family pool.
---

# Cross-family — another CLI's opinion, one command

Turns a diff, a spec draft or a stuck bug into one anchored answer from a different CLI — or into the caller's fallback when no member can run.

The runner is `scripts/cross-family.sh` in this skill's folder (`bash <this skill's folder>/scripts/cross-family.sh …`); below, `cross-family.sh` names it.
Outside Claude add `--lead <codex|agy|cursor|opencode>`. `--help` lists every flag.

## Skip when

- The pool is off and the user did not ask to set it up — the caller runs its fallback (step 5). Off is the user's choice, never a limitation to nag about.
- The ask is a review by the Lead's own CLI — that is `review-code`'s internal pass.

### 1. Resolve the pool

`cross-family.sh --pool` prints the resolved pool and why each member is in or out.
- The pool is opt-in and machine-wide, set in `~/.rolepod/config.json` under the `pool` key: run `--pool` first to see what is in force. An unset key or `pool.cross-family: "off"` = off. Never turn it on unasked.
- A wide-effort session (Claude ultracode — a keyword turn or the session setting; Codex `ultra` — proactive delegation active) runs no cross-family member: every kind takes its pool-off path, and the Cross-model line reads `NOT RUN — wide-effort session`, the user's choice like `cross-family off (opt-in)`. An explicit user ask for another CLI's opinion still runs.
- Only the Lead's own CLI is excluded. The model family is recorded as information, never a filter: a member on the Lead's vendor still counts, and a member reporting no family is a FULL external pass.
- The user asked to set up or change the pool → step 6 first.
- The user asked for another CLI's opinion and the pool is off → say so and offer step 6 once; write no file without their yes.

Done when: at least one usable member is listed, or the pool is off / empty and step 5's fallback is named.

### 2. Write the brief

The brief file is the member's whole world: cold context, never a pointer to the session or the plan file.
- Write the brief and any diff to attach outside the work tree (`${TMPDIR:-/tmp}`): a file inside it lands in the next `git add -A` and in the reviewer's live tree. Delete them once the runner returns — a detached job keeps its own copy.
- Every kind: the intent in one sentence, the acceptance criteria, the settled decisions, the risk profile, the claimed behaviours to trace.
- critique: the draft spec plus the Q&A ledger — every question already asked, numbered, with its answer. An incomplete ledger brings back questions the user already answered.
- consult: the attempt ledger — symptom, repro command, each failed fix and why it failed, the suspect code inline — and the one question.

The runner adds the kind's framing (review: one axis per lens or `--adversarial`; see `review-code` for the pool-on round 1 routing), the verdict contract and the time budget itself. Cross-family's lens or adversarial argument is a reviewer protocol, not the `workflow.mode` intensity.

Done when: the brief file exists and a stranger could act on it alone.

### 3. Run the kind

| Kind | Fires when (the caller owns this) | Command | Mode |
|---|---|---|---|
| review | round 1, pool on: one run per lens (`--lens spec`, `--lens standards`); Full R4 adds `--adversarial`; see `review-code` for routing | `--kind review [--lens spec` or `--lens standards` or `--adversarial] --brief <brief> --attach <diff> --detach` | background job |
| critique | `write-spec` step 5 owns the trigger; no `write-spec` → only when the user asks | `--kind critique --brief <draft+ledger>` | foreground, 10 min |
| consult | `debug-issue` after 2 failed attempts | `--kind consult --brief <ledger>` | foreground, short budget |

**The user named a CLI** ("a second opinion from codex") → add `--member <cli>`: that member alone, never a fall-through to another.
- Exit 9 (not usable: not in the pool, not installed, or the Lead) or exit 3 (it ran and failed) → tell the user what is usable, in pool order (the runner prints it), and ask whether to run the first one; never switch unasked. Yes → the same command without `--member`.
- The pool is off (exit 5) → step 1: say so and offer step 6 once.

**review**
- Attach `git diff HEAD` for uncommitted work (staged + unstaged) or `git diff <base>...HEAD` for a committed branch.
- `--cached` alone is a slice: the runner refuses it while the same files carry unstaged edits. `--partial-ok` only when the user asked for the staged part.
- Pool on at R3/R4: each lens runs as its own external (two runs, same pool order, same frozen diff). Full R4 adds the external adversarial pass; R2 keeps internal lenses. Round 1 only; see `review-code` for the routing rule.
- Round 2+ is the internal re-check in `review-code` Fix-verify, never a new external round.
- Its verdict, APPROVED or REJECTED, completes the pass; a REJECTED external is never re-run for an APPROVED. An external adversarial pass runs only in `full` mode.
- The diff stays frozen until the last reviewer returns: no edit to its files, no `git stash` / `reset` / `checkout`.
- Then do the next task outside the diff. ONE `cross-family.sh --collect <job-id> --root <git-root>` — it waits; its report joins the round's other reports.
- Member order, `--all`, what anchors, the degradation table → `references/review.md`.

**critique**
- The member returns every material item, no cap, ranked by implementation risk: `QUESTION` (only the user can decide), `AMBIGUITY` (quoted wording two engineers would read differently), `MISSING` (an acceptance criterion, failure mode or edge case with no "proven by") — or `NO FURTHER QUESTIONS`.
- Once per spec, and the triage of its items → `write-spec` step 5 (the caller's rules); no `write-spec` → hand the ranked items to the user, never re-run it on a revised draft, never block the spec.

**consult**
- FOREGROUND, short budget — a stuck loop needs the answer now. The pool's `reviewer.consult` order (e.g. `"consult": "agy codex"` — `references/pool.md`; unset → the `review` order) puts the fast member first and keeps the deep one as fallback.
- No usable member → the vertical fallback (`debug-issue` Second opinion item 2 holds the recipe); no `debug-issue` → the Lead's own CLI at its strongest model, valid only when it differs from the running one. It never counts as a cross-family pass.

Done when: the kind ran in its mode, or the runner returned an exit for step 4.

### 4. Read the return

The receipt is the last stdout line: `ROLEPOD-XFAM ok kind=<k> cli=<cli> family=<family> raw=<path> secs=<n>`.
The runner ran the member on its own default model — review / consult / critique read-only — in a clean room (`ROLEPOD_BRAIN_SILENT=1`), and anchored the output under `.rolepod/evidence/external/` with its phase-log line.
- A review counts only with its `VERDICT:` line. PARTIAL or no verdict → kept as `*.partial.txt`; the chain moves to the next member.
- A weak review — empty or partial, a bare verdict, no claims walked, a changed file missing from its Scope list → the caller adds its internal strong pass and records why.
- Consult and critique answers marked PARTIAL still count.
- A non-zero exit → `references/exits.md` (each exit and its next move, the stall and foreground caps); no `references/exits.md` → exit 2 → fix the command, never a fallback; 6 → `--collect` again later; 7 → attach the full diff; 8 → `--collect` or `--kill` the live job first; 3, 4, 5 → step 5's named fallback (`--member` given: 3 or 9 → step 3's named-CLI rule).

Done when: the answer is in hand with its receipt, or the exit is mapped to step 5.

### 5. Hand back

- Called by a skill → return to that step: review → the report path and verdict; critique → the ranked items; consult → the opinion.
- Pool off, empty or failed → the caller's fallback, with the reason for its record:
  - review → the internal strong reviewer; Cross-model line `NOT RUN — cross-family off (opt-in)` or `NOT RUN — <runner reason>`;
  - critique → skip; `Cross-family critique: not run — off` or `— <runner reason>`;
  - consult → the vertical fallback (`debug-issue` Second opinion item 2; no `debug-issue` → step 3's consult line), else stop and ask the user before another fix (`debug-issue` Second opinion item 4).
- Called alone → report to the user: the member, its verdict or answer, the raw path, and the next move you recommend.

Done when: the caller or the user holds the answer or the named fallback.

### 6. Set up the pool — on request only

The user asks to set up, enable or change cross-family, in any wording or language; never raise it unprompted. `cross-family.sh --setup` lists the installed CLIs (one → nothing to set; say so); ask ONE question — which CLIs review, in order, the Lead's own CLI included (skipped at run time; no → `none`) — then `cross-family.sh --setup review="…"` and show `cross-family.sh --pool`.
Hand-editing → `references/pool.md` (the `pool` JSON shape, per-kind order, `stall=` / `timeout=`, precedence); no `references/pool.md` → change it only through `cross-family.sh --setup review="…"`, never by hand. The pool lives only in `~/.rolepod/config.json`, no project override.

Done when: the file is written and `--pool` is shown to the user.

## Guardrails

- Every external call goes through the runner so it is anchored. Never a hand-rolled CLI call, a hand-typed evidence line, or a model / effort flag on a member. Never pin a vendor model name in a skill or plan — the routing layer resolves them.
- The user owns the pool. Never enable, widen or re-ask it unprompted.

## Next phase

- Called by a skill → back to that skill's step with the answer or the fallback.
- Called alone → the report is the deliverable; review findings to fix → `review-code` Author response.
- If `review-code` is not available, or `scripts/cross-family.sh` is missing from this skill's folder, hand the user the report or the caller's fallback from step 5.
