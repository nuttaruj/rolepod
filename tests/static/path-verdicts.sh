#!/bin/bash
# path-verdicts — one path, one verdict at edit AND commit time (spec
# gate-evidence-paths-2026-09-24, F4/F5/F6, Desired 3/4/5/9, S4).
#
# A fixture table (path -> edit kind, commit-time high-risk, gate-reminder
# banner, plan-lint security/R4) is asserted against every hand-maintained
# copy: hooks/lib/session_state.py, hooks/gate-reminder.sh, and
# the commit gate's own filter (precommit-gate.sh — EXTRACTED, never
# re-implemented, so this test cannot silently drift from the real gate).
# adapters/opencode/plugin/rolepod.js no longer carries its own copy of this
# filter (hook-layer-lean fix round, 2026-09-25, B-spec MAJOR): its commit
# hook runs hooks/precommit-gate.sh itself (ROLEPOD_LEAD_CLI=opencode), so
# there is no JS regex twin left to drift and check here. The edit ledger
# (hooks/edit-ledger.py) was removed (spec Desired 10, 2026-09-25) —
# Claude-only evidence now comes from the transcript scan alone, so this
# test no longer checks it either.
set -u
cd "$(dirname "$0")/../.."
fail=0
pass() { echo "  ✓ $1"; }
bad()  { echo "  ✗ $1"; fail=$((fail + 1)); }

R="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-pv.XXXXXX")"
trap 'rm -rf "$R" "$PLANDIR"' EXIT
git -C "$R" init -q >/dev/null 2>&1

# ── extracted, not re-implemented: the commit gate's own risk_filter() body
# and its HIGH_RISK= filename/prose/risk pipeline (precommit-gate.sh:729) ──
GATE_RISK_FILTER=$(awk '/^risk_filter\(\) \{/,/^\}/' hooks/precommit-gate.sh)
GATE_HIGH_RISK_LINE=$(grep -m1 '^HIGH_RISK=\$(echo "\$DIFF_STAT"' hooks/precommit-gate.sh)
[ -n "$GATE_RISK_FILTER" ] && [ -n "$GATE_HIGH_RISK_LINE" ] || { echo "  ✗ could not extract the commit gate's risk_filter / HIGH_RISK= line — precommit-gate.sh shape changed"; exit 1; }

commit_high_risk() {  # $1 = repo-relative path -> 1 / 0
  ( cd "$R" && eval "$GATE_RISK_FILTER"
    DIFF_STAT=$(printf '0\t0\t%s' "$1")
    eval "$GATE_HIGH_RISK_LINE"
    [ -n "$HIGH_RISK" ] && echo 1 || echo 0 )
}

PLANDIR="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-pv-plan.XXXXXX")"
planlint_r4() {  # $1 = repo-relative path -> 1 / 0
  cat > "$PLANDIR/p.md" <<EOF
# Fixture Plan
### Task 1: fixture
- [ ] Files: $1
- [ ] Command: true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
  TIER=$(bash core/skills/write-plan/scripts/plan-lint.sh --brief 1 "$PLANDIR/p.md" 2>/dev/null | awk '/^## Tier/{getline; print}')
  case "$TIER" in R4*) echo 1 ;; *) echo 0 ;; esac
}

# ── S4's explicit fixture rows: path|edit_kind|commit_risk|banner|planlint_r4
FIXTURES=$'
src/auth/test_login.py|test|0|0|1
src/billing/InvoiceTest.java|test|0|0|1
spec/models/payment_spec.rb|test|0|0|1
tests/fixtures/seed_auth_users.py|test|1|1|1
src/oauth/callback.ts|risk|1|1|1
hooks/lib/session_state.py|other|0|0|0
api/specs/auth.yaml|test|1|1|1
src/auth/login.test.mjs|test|0|0|1
.cursor/rules/auth.mdc|other|0|0|0
'

# ── one row per alternative of the commit gate's test-name filter (Desired
# 9) — all under a risk-looking directory, proving the filename exemption
# overrides the path's own risk term at both commit time and the banner.
FIXTURES+=$'
src/auth/x.test.mjs|test|0|0|1
src/auth/x.spec.cjs|test|0|0|1
src/auth/x_test.php|test|0|0|1
src/auth/x_spec.rb|test|0|0|1
src/auth/test_foo.go|test|0|0|1
src/auth/FooTests.swift|test|0|0|1
src/auth/FooTest.scala|test|0|0|1
src/auth/FooTests.java|test|0|0|1
src/auth/FooTest.kt|test|0|0|1
src/auth/FooTests.cs|test|0|0|1
'

# ── case-sensitivity parity (2026-09-24 review, MAJOR-1): the commit gate's
# own filename filter has no -i, so a lowercase `test` collision inside an
# unrelated word must NOT be exempted at edit time either.
FIXTURES+=$'
src/auth/AppAttest.swift|risk|1|1|1
src/auth/Latest.java|risk|1|1|1
src/auth/TEST_helpers.py|risk|1|1|1
'

# ── breaker round 2, class test 3: `invoice.TEST.py` (uppercase infix) must
# match the gate — the `.test.` alternative is case-sensitive as a whole,
# same group as the other filename alternatives, so an uppercase `.TEST.`
# is not exempt either at edit time or at commit time.
FIXTURES+=$'
src/invoice.TEST.py|risk|1|1|1
'

# ── one row per risk term (Desired 9) — a plain code file under each term's
# own directory: risk edit, high-risk at commit, banner, plan-lint R4.
for term in auth authn authz authentication authorization \
            billing payment payments migration migrations \
            credit credits permission permissions secret secrets \
            crypto cryptography token tokens oauth jwt sso saml \
            webhook webhooks stripe paypal charge charges \
            invoice invoices deletion deletions erasure gdpr security; do
  FIXTURES+=$'\n'"src/$term/handler.ts|risk|1|1|1"
done

# ── session_state.py: ONE python pass classifies every fixture path ────
SS_PATHS=$(printf '%s\n' "$FIXTURES" | awk -F'|' 'NF>=5{print $1}')
SS_OUT=$(printf '%s\n' "$SS_PATHS" | python3 -I -c "
import sys
sys.path.insert(0, 'hooks/lib')
import session_state as s
for line in sys.stdin:
    p = line.rstrip('\n')
    if not p: continue
    if s.is_test_file(p): k = 'test'
    elif s.is_high_risk_path(p) and s.is_code_file(p): k = 'risk'
    else: k = 'other'
    hr = '1' if s.is_high_risk_path(p) else '0'
    print(p + '|' + k + '|' + hr)
")

n=0
while IFS='|' read -r path exp_kind exp_commit exp_banner exp_planlint; do
  [ -n "$path" ] || continue
  n=$((n + 1))

  ss_kind=$(printf '%s\n' "$SS_OUT" | awk -F'|' -v p="$path" '$1==p{print $2; exit}')
  commit=$(commit_high_risk "$path")
  planlint=$(planlint_r4 "$path")

  ok=1
  [ "$ss_kind" = "$exp_kind" ] || { ok=0; echo "      session_state: $path -> $ss_kind (want $exp_kind)"; }
  [ "$commit" = "$exp_commit" ]     || { ok=0; echo "      commit gate:   $path -> $commit (want $exp_commit)"; }
  [ "$planlint" = "$exp_planlint" ] || { ok=0; echo "      plan-lint:     $path -> $planlint (want $exp_planlint)"; }
  [ "$ok" -eq 1 ] || bad "verdict mismatch: $path"
done <<< "$FIXTURES"

[ "$fail" -eq 0 ] && pass "$n path-verdict rows agree across session_state / the commit gate / plan-lint"

# ── breaker round 2, class test 1: an absolute path under a root-anchored
# `-^design_tokens/` exclude gets the SAME verdict as its relative form, in
# every copy that can see an absolute path — the ledger, the banner, and
# session_state.count_all (a transcript's Edit file_path is typically
# absolute).
mkdir -p "$R/.rolepod" "$R/design_tokens"
printf -- '-^design_tokens/\n' > "$R/.rolepod/risk-paths"
CT1_ABS="$R/design_tokens/token_store.py"
CT1_REL="design_tokens/token_store.py"
CT1_TRANSCRIPT="$PLANDIR/ct1-transcript.jsonl"
SS_ABS="$(pwd)/hooks/lib/session_state.py"
count_all_of() {  # $1 = file_path to embed in a one-edit transcript; run
  # from $R's own cwd, matching production (the hook's process cwd IS the
  # repo being edited) — session_state's risk-paths override is a
  # module-level singleton bound to process cwd, not the hook input's cwd.
  printf '{"type":"tool_use","name":"Edit","input":{"file_path":"%s"}}\n' "$1" > "$CT1_TRANSCRIPT"
  ( cd "$R" && printf '{"transcript_path":"%s","cwd":"%s"}' "$CT1_TRANSCRIPT" "$R" \
    | python3 -I "$SS_ABS" count-all "" 2>/dev/null )
}
CT1_ABS_COUNT=$(count_all_of "$CT1_ABS")
CT1_REL_COUNT=$(count_all_of "$CT1_REL")
if [ "$CT1_ABS_COUNT" = "$CT1_REL_COUNT" ] && [ "$(echo "$CT1_ABS_COUNT" | awk '{print $2}')" = "0" ]; then
  pass "class test 1: session_state.count_all — absolute vs relative design_tokens/token_store.py agree (high_risk_edits=0, excluded)"
else
  bad "class test 1: count_all mismatch — abs=[$CT1_ABS_COUNT] rel=[$CT1_REL_COUNT]"
fi

rm -f "$R/.rolepod/risk-paths"

# ── breaker round 2, class test 2: an ancestor directory named `auth`
# OUTSIDE the repo must not make an ordinary repo file look risky.
CT2_PARENT="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-pv-auth.XXXXXX")"
CT2_ROOT="$CT2_PARENT/auth/repo"
mkdir -p "$CT2_ROOT/src"
git -C "$CT2_ROOT" init -q >/dev/null 2>&1
CT2_ABS="$CT2_ROOT/src/util.ts"
printf 'x = 1\n' > "$CT2_ABS"

CT2_TRANSCRIPT="$PLANDIR/ct2-transcript.jsonl"
printf '{"type":"tool_use","name":"Edit","input":{"file_path":"%s"}}\n' "$CT2_ABS" > "$CT2_TRANSCRIPT"
CT2_COUNT=$( cd "$CT2_ROOT" && printf '{"transcript_path":"%s","cwd":"%s"}' "$CT2_TRANSCRIPT" "$CT2_ROOT" \
  | python3 -I "$SS_ABS" count-all "" 2>/dev/null )
[ "$(echo "$CT2_COUNT" | awk '{print $2}')" = "0" ] \
  && pass "class test 2: session_state.count_all — ancestor dir 'auth' outside the repo is not a risk edit" \
  || bad "class test 2: count_all=[$CT2_COUNT]"
rm -rf "$CT2_PARENT"

echo
if [ "$fail" -eq 0 ]; then echo "path-verdicts: pass ($n rows)"; exit 0; fi
echo "path-verdicts: FAIL ($fail)"; exit 1
