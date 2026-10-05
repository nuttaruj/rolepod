---
name: run-review
description: Use when a built diff needs its review round ordered — freeze it, pick the reviewer set, dispatch, take the reports, run Fix-verify; a track ends; the user asks to review a diff, branch or PR.
---

# Run Review

A built diff → its round-1 reviewer set run on one frozen snapshot, findings closed through Fix-verify.

## Skip when

- R1: ≤ 5 lines, one file, zero logic, not high-risk.
- Docs-only at any size.
- The user accepts the change unreviewed.
- You were dispatched to review → `review-code`.

### 1. Freeze the diff

- Uncommitted work → `../implement-plan/scripts/ticket.sh review-diff start <task>` (paths relative to this skill's folder; `<task>` = the brief's report name, else a short one) prints the diff file and H1.
- No script → `git add -A`; the staged `--stat` + `-U10` diff, excluding `docs/rolepod` and lockfiles, into `.rolepod/evidence/review/<task>.diff`; H1 = `git write-tree`.
- Committed (a track end: the lens diff `ticket.sh log` wrote; a branch / PR: `git diff <base>...<head>`, same excludes, into `<task>.diff`) → that file; H1 = `git rev-parse <head>^{tree}`.
- Record the hash beside H1: `git hash-object <diff file>`. Preflight: refs resolve, diff non-empty; else re-derive, never dispatch.
- Past ~15 files / ~800 lines → split, one review each: a track end by size slice (`run-tracks` step 4; none → by task in plan order), else by task or ship group.
- Gather spec / plan / acceptance, touched files and risk profile; a track end also: the `Track end:` and `Review:` lines from `ticket.sh log`.

Done when: diff file, H1 and hash recorded; inputs in hand.

### 2. Pick the set

- The two lenses = `universal-reviewer` `lens: spec` + `lens: standards`.
- The brief's Reviewers or `Review:` line wins; none → `../write-plan/scripts/plan-lint.sh --review-set --tier <R2|R3|R4> [--match <perf,ui,arch>]`. A high-risk path (auth, money, secrets, tokens, crypto, permissions, migration, data deletion) in the unreviewed diff → R4 regardless.
- No script → the Review set below at the carried mode, never re-read; none carried → `using-rolepod`'s `scripts/workflow-mode.sh` once.

**Review set** (round 1; mode unknown → Lite). Lite, any tier: the two lenses only. Standard: R2 the two lenses, a matched row → that role instead · R3 the two lenses + each matched specialist · R4 the two lenses + `security-engineer` (`depth: checklist`). Full: as Standard, but R4 `depth: full` + one adversarial pass.

- Matched rows: performance regression → `performance-engineer` · UI / interaction / a11y → `ui-ux-designer` · architecture / cross-module → `system-architect`.
- Pool on + R3 / R4 → each lens external via `cross-family` kind review (`--lens <lens>`); internal: R2, comment / config / rename-only diffs, a wide-effort session, `security-engineer`, specialists. A failed, weak or refused external → `universal-reviewer`, same lens, same round; no `cross-family` → internal lenses.
- Full R4 adversarial pass → `adversarial-review`; none → `universal-reviewer` `mode: adversarial`, strong-class model, writing `<task>-adversarial.md`.

Done when: each reviewer named with its lens or role.

### 3. Dispatch the round

- Each brief: its own lens or role only, never another's report; the same diff file, H1 and hash; the task block and spec clauses it covers, quoted (no plan / spec path; no spec → the user's goal); acceptance criteria; risk profile; behaviors to trace; roles already run; `mode`; report `.rolepod/evidence/review/<task>-<lens|role>.md`; read-only, no sub-agent.
- ≤ 20 tool calls per lens, ≤ 40 for `security-engineer` and the adversarial pass; `security-engineer` also gets the repo's existing scanner and stated security rules, if any.
- `universal-reviewer` → one fresh context per lens; else a default sub-agent per lens, given its lens and `review-code` if present; portable dispatch → `using-rolepod/references/model-tiers.md`, no file → the native role or a fresh child given the role's text.
- The fixes wait for every report: dispatch the whole set in ONE message, then take every report in before you fix anything.
- Cannot dispatch a reviewer → return the diff unreviewed to your caller, naming the set: `REVIEW NEEDED: <set>`.
- A Lead with no agents: Lite → walk both axes yourself (`review-code` if present), noting the lost independence; Standard / Full → blocked unless the user waives it.
- Until the round ends: no diff-file edit, no `git stash / reset / checkout / add / commit`; a missing, failed, empty or partial report keeps it open for its reviewer to complete.

Done when: every report complete at its path.

### 4. Take the reports

- Aggregate and deduplicate only once every report is in; the receipt's `## Reviews` lists each path; never re-walk a traced report.
- Full R4 Cross-model adversarial pass line: `ran on <cli>` · `NOT RUN — cross-family off (opt-in)` · `NOT RUN — wide-effort session` · `NOT RUN — <reason>` (the internal strong pass ran) · `vertical — same CLI, <reason>`.

Evidence log: append the line to `<git-root>/.rolepod/evidence/phase-log.jsonl` chained onto the next command you run anyway (`<cmd> && printf '…' >> phase-log.jsonl`), never as a standalone turn; skip silently outside a git repo.
Review line: `{"ts":"<iso8601>","phase":"review","verdict":"<APPROVED|APPROVED-WITH-NITS|REJECTED>","blockers":<n>}`.

Done when: reports listed in the receipt; review line appended.

### 5. Fix-verify

- Verify each finding against the code; by provenance: this diff → fix now; pre-existing on a changed path → only if it makes this change wrong; untouched path → `## Follow-ups`.
- Each BLOCKER / MAJOR: fixed with its proof (repro or test and result) or pushed back with a one-line reason; both go to the re-check.
- Each aggregated MINOR → Act on / Consider / Noted / Dismissed, one-line reason; filters: nitpick weight (behavior or taste?) and assumed vs actual (does the code show it?); Act on → fixed, closed on author evidence; MINORs never open a re-check.
- The delta: `ticket.sh review-diff delta <task> <H1> <k>` (`<k>` = round 2-4; H1 is a tree, committed or not); no script → `git add -A && git diff <H1> $(git write-tree) -U10`, same excludes, into `<task>-r<k>.diff`; that tree is H2.
- ONE fresh `universal-reviewer` re-checks only the delta and each pushback (held closes; reopened goes back open), ≤ 15 tool calls — never the original role, never a message to a finished reviewer.
- At most four rounds, round 1 included; review rounds never reset the failed-fix count. Open after round 4 → rule once on each open finding, one `Ruling:` line each in the receipt, then go on without waiting for the user:
  - wrong or arguable → `Ruling: <finding> — parked — <why>`;
  - real, nothing ahead depends on it → parked as real-deferred, plus one line under `## Follow-ups`;
  - real, later work depends on it → the smallest fix that unblocks it; `Ruling: <finding> — <decision + why>` in the decision brief.
- Who fixes: a round-2 fix → the same owner; a round-3 or round-4 fix → a fresh owner of the same role one tier higher (strong at most), given the open findings verbatim, the receipt path and "A prior owner fixed this <N> times; you own it now — read the receipt for what was tried." Cannot dispatch → return the open findings to your caller.
- A finding closes at the receipt only (repro or test, H1→H2 paths + delta hash, H2); a green suite alone closes nothing.
- Pushback / YAGNI → `../review-code/references/receiving-findings.md`; no file → per finding, the fix or a reasoned pushback.

Done when: each BLOCKER / MAJOR closed at the receipt, held, or ruled at the cap; each MINOR sorted with its reason.

## Next phase

- Every finding closed or ruled → back to the caller: a task owner returns its decision brief; a Lead review → `check-work` when fixes landed, else `finish-work`.
- Not available → `review-code` on the diff.
- No other skill → stop and tell the user what changed, what was verified and what is still unverified or unreviewed.

The stop line carries the report paths, H1 and H2, and each open finding with its file:line.
