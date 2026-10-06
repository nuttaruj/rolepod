<!-- Rolepod finish menu — the canonical Ship-phase output. -->
<!-- Present this, recommend one option, then WAIT (unless the user's own message already named the action + target, or Keep open alone). Delete the <hints>. -->

# <Branch> — Finish

## Gate status
- Pre-merge gate: <PASS / FAIL — name what failed>
- Verify status: <each receipt's VERIFIED / PARTIAL / UNVERIFIED, plus the
  full-suite block: path, Verified tree id, Status — reason>
- QA pass: <flows run → result, or "none — no user-visible flow" · open failures>
- CI: <each required lane: status, or no CI — local checks / cited block>
- Review verdict: <APPROVED / APPROVED-WITH-NITS / REJECTED / PARTIAL / BLOCKED>
- Cross-model adversarial pass (Full R4 only): <receipt or internal strong pass — reason>
- User waivers this session: <none, or per waiver: which gate — the user's words, quoted>

## Rulings made
<Every `Ruling:` line from this work's receipts, each with what it costs if the ruling is wrong; "none" when no ruling was made. A parked BLOCKER on a high-risk path is the user's call: ask it here, before the options.>

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
 report's `## Follow-ups`), each with its destination in the project's one
 follow-up list, or dropped — why. "none" when nothing was parked.>

## Recommendation
<The one option that fits, with a one-line why.>

## Awaiting authorization for
<The single specific action — e.g. "merge branch X to main" / "push to
 origin/X". Do not act until the user authorizes THIS action.>
