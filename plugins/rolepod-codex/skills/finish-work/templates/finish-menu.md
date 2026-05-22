<!-- Rolepod finish menu — the canonical Ship-phase output. -->
<!-- Present this, recommend one option, then WAIT. Delete the <hints>. -->

# <Branch> — Finish

## Gate status
- Pre-merge gate (S + T + F): <PASS / FAIL — name what failed>
- CI: Phase 1 <status> · Phase 2 <status, or n/a>
- Review verdict: <APPROVED / APPROVED-WITH-NITS / REJECTED>

## Options
1. **Merge to main** — ready because <evidence the gates are green>
2. **Open PR** — useful because <needs upstream review / CI on the PR runner>
3. **Keep open** — useful because <work remaining>
4. **Discard** — safe because <experiment; backup tagged>

## Recommendation
<The one option that fits, with a one-line why.>

## Awaiting authorization for
<The single specific action — e.g. "merge branch X to main" / "push to
 origin/X". Do not act until the user authorizes THIS action.>
