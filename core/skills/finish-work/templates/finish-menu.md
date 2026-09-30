<!-- Rolepod finish menu — the canonical Ship-phase output. -->
<!-- Present this, recommend one option, then WAIT (unless the user's own message already named the action + target, or Keep open alone). Delete the <hints>. -->

# <Branch> — Finish

## Gate status
- Pre-merge gate (S/T/F/P — simplicity, test, failure-mode, PR scope): <PASS / FAIL — name what failed>
- Evidence status (from check-work's evidence block): <VERIFIED / PARTIAL /
  UNVERIFIED — reason. PARTIAL / UNVERIFIED blocks merge unless waived.>
- CI: Phase 1 <status> · Phase 2 <status, or n/a>
- Review verdict: <APPROVED / APPROVED-WITH-NITS / REJECTED>
- Cross-model adversarial pass (high-risk diff only): <ran on `<cli>`
  (cross-family) / ran on `<cli>`, model family not reported (still clears
  the gate) / cross-family off (opt-in — the user's choice, no limitation)
  / wide-effort session (the user's choice, no limitation) / vertical — same CLI / NOT RUN — reason. Vertical or a NOT RUN other
  than opt-in-off or wide-effort session is a limitation the user must see.>
- User waivers this session: <none, or per waiver: which gate — the user's
  words, quoted. A waiver is recorded here, never silently applied.>

## Options
<Detached HEAD (finish-work Detect the environment) → drop Merge to main, leaving 2 options: PR and Keep open. Discard available only on explicit user request — never presented as a standard option.>
1. **Merge to main** — ready because <evidence the gates are green>
2. **Open PR** — useful because <needs upstream review / CI on the PR runner>
3. **Keep open** — useful because <work remaining>

## If user explicitly asks to discard
- Branch to delete: <branch name>
- Commits to lose: <list of commit shas from branch not in main>
- Worktree at: <path will be deleted>
- Backup suggestion: `git tag backup-<branch> -m "backup before discard"` to save the commits before deletion
- **To proceed:** type the word `discard` to confirm. (A generic "yes" is not confirmation.)

## Follow-ups carried
<Every line from the plan's `## Follow-ups` (no plan file → each review
 report's `## Follow-ups`), each with a destination: backlog line (issue tracker, else docs/rolepod/backlog.md) / next spec (repeat
 feature) / issue #n / dropped — why. "none" when nothing was parked. A
 parked idea never leaves the branch silently.>

## Recommendation
<The one option that fits, with a one-line why.>

## Awaiting authorization for
<The single specific action — e.g. "merge branch X to main" / "push to
 origin/X". Do not act until the user authorizes THIS action.>
