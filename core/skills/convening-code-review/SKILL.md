---
name: convening-code-review
description: Use when the user asks to review a diff, branch or PR, or a track ends; a built diff needs its review round ordered.
---

# Convening Code Review

A built diff → its round-1 reviewer set run on one frozen snapshot, findings closed through Fix-verify.

## Skip when

- R1: ≤ 5 lines, one file, zero logic, not high-risk.
- Docs-only at any size, except a phase-end pass (`orchestrating-plans`).
- The user accepts the change unreviewed.
- You were dispatched to review → `review-code`.

### 1. Freeze the diff

- Uncommitted work → `../implement-plan/scripts/ticket.sh review-diff start <name> [-- <path>...]` (the script relative to this skill's folder; `<name>` = `<task>`, the brief's report name, else a short one; each `<path>` relative to the checkout root, literal: the brief's Files plus each `Also touched:` path) prints the diff file and H1; no path list → the whole tree, and its limitation line goes in the receipt.
- No script → `git add -A -- <paths>`; the staged `--stat` + `-U10` diff of those paths, excluding `docs/rolepod`, lockfiles and each `.rolepod/review-exclude` line, into `.rolepod/evidence/review/<task>.diff`; H1 = `git write-tree`.
- Committed (a track end: the lens diff `ticket.sh log` wrote; a branch / PR: `git diff <base>...<head>`, same excludes, into `<task>.diff`) → that file; H1 = `git rev-parse <head>^{tree}`.
- Record the hash beside H1: `git hash-object <diff file>`. Preflight: refs resolve, diff non-empty; else re-derive, never dispatch.
- Past ~15 files / ~800 lines → split, one review each: a track end by size slice (`coordinating-parallel-tracks` step 4; none → by task in plan order), else by task.
- Gather spec / plan / acceptance, touched files and risk profile; a track end also: the `Track end:` and `Review:` lines from `ticket.sh log`.

Done when: diff file, H1 and hash recorded; inputs in hand.

### 2. Pick the set

- Every reviewer = `rolepod-reviewer` + a `lens:`; the two lenses = `lens: spec` + `lens: standards`; a Standard / Full R2 with no plan or spec → the standards lens only.
- The brief's Reviewers or `Review:` line wins; none → `../write-plan/scripts/plan-lint.sh --review-set --tier <R2|R3|R4> [--match <perf,ui,arch>]`. A high-risk path in the unreviewed diff → R4 regardless:

{{INCLUDE: core/fragments/risk-paths.md}}

- No script → the Review set below at the carried mode, never re-read (a config change takes effect in a new session); none carried → `using-rolepod`'s `scripts/workflow-mode.sh` once. A helper or `plan-lint.sh` call without the native mode environment gets `ROLEPOD_SESSION_MODE` and `ROLEPOD_SESSION_SOURCE` from the carried profile.

{{INCLUDE: core/fragments/review-set.md}}

- Matched rows: performance regression → `lens: perf` · UI / interaction / a11y → `lens: ui` · architecture / cross-module → `lens: arch`; the writer's unit tests are the floor, and user-visible behaviour (a UI / E2E flow) is no review row — `rolepod-qa` observes it at Ship.
- Pool on + R3 / R4 → each lens external via `cross-family` kind review (`--lens <lens>`); internal: R2, comment / config / rename-only diffs, a wide-effort session, `lens: security`, specialists. A failed, weak or refused external (weak = an empty or PARTIAL return, a changed file missing from its Scope list, a bare verdict, or no claim walked) → `rolepod-reviewer`, same lens, same round; no `cross-family` → internal lenses.
- Full R4 adversarial pass: pool on → the external `cross-family` run with `--adversarial`, which is then the only adversarial pass; else `rolepod-reviewer` `lens: adversarial` (strong, given `adversarial-review`), writing `<task>-adversarial.md` — also when the external fails, is refused (exit 2) or comes back weak, as for a lens.
- No `rolepod-reviewer` type → a default sub-agent on a strong-class model, given `adversarial-review` and its brief. An R4 diff of comments or blank lines only gets no adversarial pass and no external. The vertical fallback and an inline advisor only raise the Lead floor, recorded as a LIMITATION; those two, the author's own model and the Lead's own walk never count as this pass.
- A high-risk fix after verification → the track-end review; after it, the Fix-verify re-check (Standard / Full: `lens: security`).

Done when: each reviewer named with its lens or role.

### 3. Dispatch the round

- Each brief: its own lens or role only, never another's report; the same diff file, H1 and hash; the task block and spec clauses it covers, quoted (no plan / spec path; no spec → the user's goal); acceptance criteria; risk profile; behaviors to trace; roles already run; report `.rolepod/evidence/review/<task>-<lens>.md`, `<lens>` one of `spec` · `standards` · `security` · `adversarial` · `perf` · `ui` · `arch`; read-only, no sub-agent.
- Spec lens only: the writer's Command and the tail of its result, quoted — unverified claims; check them against the diff and the tests, never re-run them; the writer's reasons never lower a finding's severity.
- ≤ 20 tool calls per lens, ≤ 40 for `lens: security` and the adversarial pass; the security lens also gets the result of the repo's own security scanner (audit, secret scan, security lint) on the changed files and the project's stated security rules, quoted as its checklist — none present → none added, never invent one.
- `rolepod-reviewer` → one fresh context per lens; else a default sub-agent per lens, given its lens and `review-code` if present; portable dispatch → `using-rolepod/references/model-tiers.md`, no file → the native role or a fresh child given the role's text.
- The fixes wait for every report: dispatch the whole set in ONE message.
- Cannot dispatch a reviewer → return the diff unreviewed to your caller, naming the set: `REVIEW NEEDED: <set>`.
- A Lead with no agents: Lite → walk both axes yourself (`review-code` if present), noting the lost independence; Standard / Full → blocked unless the user waives it. The Lead's own walk is never an independent reviewer; strength routing never removes a required axis; the user forbids agents → surface the conflict.
- Until the round ends: no diff-file edit, no `git stash / reset / checkout / add / commit` (a red-proof revert runs in a throwaway worktree). A missing, failed, empty or partial internal report keeps the round open: that same isolated reviewer completes it on the same frozen diff — never a Lead review, never a second round — and the recommendation stays PARTIAL until every report is complete.

Done when: every report complete at its path.

### 4. Take the reports

- Aggregate and deduplicate only once every report is in; the receipt's `## Reviews` lists each path; never re-walk a traced report. A bare `APPROVED`, or a clean verdict whose Scope skips a changed file or whose Read names no files, behaviors or trace paths, is PARTIAL: the round stays open.
- Full R4: write the Cross-model adversarial pass line into the receipt's `## Reviews`: `ran on <cli>` · `NOT RUN — cross-family off (opt-in)` · `NOT RUN — wide-effort session` · `NOT RUN — <reason>` (the internal strong pass ran) · `vertical — same CLI, <reason>`.

{{INCLUDE: core/fragments/phase-log.md}}
Review line: `{"ts":"<iso8601>","phase":"review","verdict":"<APPROVED|APPROVED-WITH-NITS|REJECTED>","blockers":<n>}`.

Done when: reports listed in the receipt; review line appended.

### 5. Fix-verify

- Verify each finding against the code; by provenance: this diff → fix now (a behavior the diff changed or lost outside its own lines counts, even filed as a question or follow-up); pre-existing on a changed path → only if it makes this change wrong, else a user decision (money / auth) or `## Follow-ups`; untouched path → `## Follow-ups`. Every Follow-up goes into the plan's `## Follow-ups` (no plan file → the finish menu's Follow-ups).
- Each BLOCKER / MAJOR: fixed with its proof (repro or test and result) or pushed back with a one-line reason; both go to the re-check.
- Each aggregated MINOR → Act on / Consider / Noted / Dismissed, one-line reason; filters: nitpick weight (behavior or taste?) and assumed vs actual (does the code show it?); Act on → fixed, closed on author evidence; MINORs never open a re-check.
- The delta: `ticket.sh review-diff delta <task> <H1> <k>` (`<k>` = round 2-4; H1 is a tree, committed or not); no script → `git add -A && git diff <H1> $(git write-tree) -U10`, same excludes, into `<task>-r<k>.diff`; that tree is H2. A change in H2 outside every finding's fix is uncovered: surface it and route it at its own tier.
- Round 2+ runs in every mode and tier: ONE fresh `rolepod-reviewer` re-checks only the delta, ≤ 15 tool calls, report `<task>-r<k>.md` — never the original role, never a message to a finished reviewer. Its verdict per finding: each BLOCKER / MAJOR ADDRESSED or NOT ADDRESSED at file:line; each pushback HELD (closes) or REOPENED (open again); a new break inside the delta joins the open list; one outside it goes to `## Follow-ups` and never adds a round.
- At most four rounds, round 1 included; failed fixes count apart under `debug-issue`'s rule (no `debug-issue` → a review rejection is not a failed fix, and a new reviewer or owner resets neither count). Open after round 4 → rule once on each open finding, one `Ruling:` line each in the receipt, then go on without waiting for the user:
  - wrong or arguable → `Ruling: <finding> — parked — <why>`;
  - real, nothing ahead depends on it → parked as real-deferred, plus one line under `## Follow-ups`;
  - real, later work depends on it → the smallest fix that unblocks it; `Ruling: <finding> — <decision + why>` in the decision brief.
- Who fixes: a round-2 fix → the same owner; a round-3 or round-4 fix → a fresh owner of the same role one tier higher (strong at most), given the open findings verbatim, the receipt path and "A prior owner fixed this <N> times; you own it now — read the receipt for what was tried." Cannot dispatch → return the open findings to your caller.
- A finding closes at the receipt only (repro or test, H1→H2 paths + delta hash, H2); a green suite alone closes nothing.
- Pushback / YAGNI → `../review-code/references/receiving-findings.md`; no file → per finding, the fix or a reasoned pushback.

Done when: each BLOCKER / MAJOR closed at the receipt, held, or ruled at the cap; each MINOR sorted with its reason.

## Next phase

- A review-only ask (no fix, no ship) → stop after handing over the report: it is the deliverable, even with findings or unchecked plan tasks.
- Every finding closed or ruled → back to the caller: a task owner returns its decision brief; a Lead review ends back at the plan's next step (`orchestrating-plans`: the next task or the final branch review), else `finish-work`.
- Not available → `review-code` on the diff.
- No other skill → stop and tell the user what changed, what was verified and what is still unverified or unreviewed.

The stop line carries the report paths, H1 and H2, and each open finding with its file:line.
