---
name: cross-family
description: Get another CLI's opinion or draft through the cross-family runner — a cold adversarial review of a diff, a spec critique, a stuck-bug consult, or a ticket drafted by another CLI — and set up the opt-in pool. Use when a calling skill names a kind, the user asks for a second opinion from codex / agy / cursor / opencode / claude, or the user asks to set up or change cross-family.
---

# Cross-family — another CLI's opinion, one command

Turns a diff, a spec draft, a stuck bug or a test-first ticket into one anchored answer from a different CLI — or into the caller's fallback when no member can run.

The runner is `scripts/cross-family.sh` in this skill's folder (`bash <this skill's folder>/scripts/cross-family.sh …`); below, `cross-family.sh` names it.
Outside Claude add `--lead <codex|agy|cursor|opencode>`. `--help` lists every flag.

## Skip when

- The pool is off and the user did not ask to set it up — the caller runs its fallback (step 5). Off is the user's choice, never a limitation to nag about.
- The ask is a review by the Lead's own CLI — that is `review-code`'s internal pass.

### 1. Resolve the pool

`cross-family.sh --pool` prints the resolved pool and why each member is in or out.
- The pool is opt-in: `<git-root>/.rolepod/cross-family` overrides `~/.rolepod/cross-family`. No file or `none` = off. Never turn it on unasked.
- Only the Lead's own CLI is excluded. The model family is recorded as information, never a filter: a member on the Lead's vendor still counts, and a member reporting no family is a FULL external pass.
- The user asked to set up or change the pool → step 6 first.
- The user asked for another CLI's opinion and the pool is off → say so and offer step 6 once; write no file without their yes.

Done when: at least one usable member is listed, or the pool is off / empty and step 5's fallback is named.

### 2. Write the brief

The brief file is the member's whole world: cold context, never a pointer to the session or the plan file.
- Every kind: the intent in one sentence, the acceptance criteria, the settled decisions, the risk profile, the claimed behaviours to trace.
- critique: the draft spec plus the Q&A ledger — every question already asked, numbered, with its answer. An incomplete ledger brings back questions the user already answered.
- consult: the attempt ledger — symptom, repro command, each failed fix and why it failed, the suspect code inline — and the one question.
- implement: the task brief with its failing test named.

The runner adds the adversarial framing, the verdict contract and the time budget itself.

Done when: the brief file exists and a stranger could act on it alone.

### 3. Run the kind

| Kind | Fires when (the caller owns this) | Command | Mode |
|---|---|---|---|
| review | `review-code` strong pass: R4, or from the pool file's `tier = R2\|R3` up | `--kind review --brief <brief> --attach <diff> --detach` | background job |
| critique | `write-spec`: R4 spec before Gate 1 (R3 stays internal), or the user asks | `--kind critique --brief <draft+ledger>` | foreground, 10 min |
| consult | `debug-issue` after 2 failed attempts | `--kind consult --brief <ledger>` | foreground, short budget |
| implement | a plan task marked `write: external` | `--kind implement --brief <task-brief> --allow <path>... --detach` | background job, collected in the foreground |

**review**
- Attach `git diff HEAD` for uncommitted work (staged + unstaged) or `git diff <base>...HEAD` for a committed branch.
- `--cached` alone is a slice: the runner refuses it while the same files carry unstaged edits. `--partial-ok` only when the user asked for the staged part.
- The external IS the strong pass: it replaces `universal-reviewer`, never both on round 1. It runs round 1 only: its BLOCKER / MAJOR fixes are re-checked by `security-engineer` on a high-risk path, else by `universal-reviewer` on a strong-class model (`review-code` Fix-verify rounds), never a new external round. The R4 floor stays `security-engineer` + that ONE strong pass — dispatch `security-engineer` in the same message.
- The diff stays frozen until the last reviewer returns: no edit to its files, no `git stash` / `reset` / `checkout`.
- Then do the next task outside the diff. ONE `cross-family.sh --collect <job-id> --root <git-root>` before the commit — it waits.
- Member order, `--all`, what anchors, the degradation table → `references/review.md`.

**critique**
- The member returns every material item, no cap, ranked by implementation risk: `QUESTION` (only the user can decide), `AMBIGUITY` (quoted wording two engineers would read differently), `MISSING` (an acceptance criterion, failure mode or edge case with no "proven by") — or `NO FURTHER QUESTIONS`.
- One critique per draft. The caller settles from the repo what it can and asks the rest in ONE extra Discovery round. It never blocks the spec.

**consult**
- FOREGROUND, short budget — a stuck loop needs the answer now. A `consult = <fast> <deep>` line in the pool file puts the fast member first and keeps the deep one as fallback.
- No usable member → the vertical fallback: the Lead's own CLI at its strongest model. Its native advisor mode when it has one; else read its `--help` for the top tier and run it headless on the same ledger (`claude -p --model <name>` / `codex exec -m <name>`). Never pin vendor model names in a skill or plan — the routing layer resolves them.
- The vertical fallback is valid only when that model differs from the one running. Already on it, or cannot tell → no usable advisor. It never counts as a cross-family pass.

**implement**
- The owner writes the failing test at the seam first; the member drafts the change that turns it green.
- `--allow` names the ticket's files; an edit outside them is reverted. A money / auth / data path needs `--allow-risky`, only when the user lifts that refusal for this ticket.
- `--collect` in the FOREGROUND, then the owner runs its own loop (Command, reviewers, fixes).
- The member never reviews its own draft: a DIFFERENT member reviews it (the runner skips the implementer while the ticket is uncommitted).

Done when: the kind ran in its mode, or the runner returned an exit for step 4.

### 4. Read the return

The receipt is the last stdout line: `ROLEPOD-XFAM ok kind=<k> cli=<cli> family=<family> raw=<path> secs=<n>`.
The runner ran the member read-only on its own default model, in a clean room (`ROLEPOD_BRAIN_SILENT=1`), and anchored the raw output under `.rolepod/evidence/external/` with its phase-log line.
- A review counts only with its `VERDICT:` line. PARTIAL or no verdict → kept as `*.partial.txt`; the chain moves to the next member.
- A weak review — empty or partial, a bare verdict, no claims walked, a changed file missing from its Scope list → the caller adds its internal strong pass and records why.
- Consult and critique answers marked PARTIAL still count.
- Exit 3 (every member failed), 4 (enabled, nothing usable), 5 (off) → step 5.
- Exit 7 (partial slice) → attach the full diff. Exit 8 (a review job is live) → collect or `--kill` it first.
- A member dies when it goes silent (`stall=`, default 600 s), not when it is slow. A foreground call is capped by the harness (Claude Bash: 600 s): run a long review with `--detach`.

Done when: the answer is in hand with its receipt, or the exit is mapped to step 5.

### 5. Hand back

- Called by a skill → return to that step: review → the report path and verdict; critique → the ranked items; consult → the opinion; implement → the collected draft.
- Pool off, empty or failed → the caller's fallback, with the reason for its record:
  - review → the internal strong reviewer; Cross-model line `NOT RUN — cross-family off (opt-in)` or `NOT RUN — <runner reason>`;
  - critique → skip; `Cross-family critique: not run — off` or `— <runner reason>`;
  - consult → the vertical fallback (step 3), else escalate;
  - implement → the owner writes the task itself.
- Called alone → report to the user: the member, its verdict or answer, the raw path, and the next move you recommend.

Done when: the caller or the user holds the answer or the named fallback.

### 6. Set up the pool — on request only

The user asks to set up, enable or change cross-family, in any wording or language. Never raise it unprompted.
1. `cross-family.sh --setup` prints the installed CLIs and two questions. One installed CLI → nothing to set; say so.
2. Ask ONE question per turn: (1) which CLIs review, in order; (2) implement: `same`, `none`, or its own order.
3. Write it: `cross-family.sh --setup review="…" implement=…`, then show `cross-family.sh --pool`.

List the Lead's own CLI too — it is skipped at run time, so switching Lead never means editing the file. The user says no → `none`.
Hand-editing the file (`tier =`, per-kind order, `stall=`) → `references/pool.md`.

Done when: the file is written and `--pool` is shown to the user.

## Guardrails

- Every external call goes through the runner so it is anchored. Never a hand-rolled CLI call, a hand-typed evidence line, or a model / effort flag on a member.
- The user owns the pool. Never enable, widen or re-ask it unprompted.

## Next phase

- Called by a skill → back to that skill's step with the answer or the fallback.
- Called alone → the report is the deliverable; review findings to fix → `review-code` Author response.
- If `review-code` is not available, or `scripts/cross-family.sh` is missing from this skill's folder, hand the user the report or the caller's fallback from step 5.
