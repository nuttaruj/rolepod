#!/bin/bash
# plan-lint — deterministic lint of a filled plan artifact, plus the
# cohesion contract when the plan declares a parallel layout. The
# mechanical arm of write-plan §7 self-review.
#
# Usage: scripts/plan-lint.sh <plan.md> [contract.md]
#   The contract argument is optional — when omitted, the script looks for
#   a backticked *.md path inside the plan's "## Parallel layout" section
#   (resolved against the plan's directory, then the repo root). A plan
#   whose Parallel layout says "Sequential" skips the ownership check.
#
# Usage: scripts/plan-lint.sh --brief <N> <plan.md> [contract.md]
#   Prints Task N's brief (Goal/Tier/Blocked by/Read first/Files allowed/
#   Files forbidden/Change/Test/Command/Check/Done when/Write/Reviewers/Bounds)
#   to stdout, assembled from the plan (and the contract's File-ownership +
#   Do-not-touch-list when one is given). Exit 0 on success; exit 2 with
#   one stderr line and empty stdout when Task N does not exist. Field
#   labels match with or without `**bold**` (real plans use both dialects).
#
# Checks:
#   1. `## Failure policy` section present (the loop's circuit breaker).
#   2. Every task block carries a `Command:` (loop-runnable). A task heading
#      is `### Task N:` or `### TN —` — both shapes appear in real plans.
#   3. Blocked-by graph (v2.90.0): every task carries `Blocked by:`, every
#      reference resolves to a task in this plan, and the graph has no cycle.
#      The graph IS the plan's order; a Sequential plan whose graph has more
#      than one root gets an advisory naming the parallel candidates.
#      A plan with NO Blocked-by fields at all (pre-v2.90.0) is advised, not
#      failed — order was prose there.
#   4. Parallel plans only: every backticked path under "## Files to touch"
#      appears under EXACTLY one owner in the contract's "## File ownership"
#      — an unowned file is unplannable work; a dual-owned file is a merge
#      conflict on schedule.
#
# Advisories (v2.144.0, never a FAIL — a Sequential plan may be legitimate):
#   a. Prefactor smell: a backticked path on the `Files:` line of >= 2 tasks
#      with no dependency path between them (neither blocks the other,
#      directly or transitively) in the Blocked-by graph.
#   b. Nothing to dispatch: a plan of >= 3 tasks whose every `Owner:` line
#      names Lead (plain, with an aside, or a role tagged "Lead self-do").
#
# Exit 0 = pass. Exit 1 = fail, every violation named on stdout.
set -uo pipefail

# Task heading regex — shared by the graph/Command checks below AND by
# --brief (reused, not re-parsed, so both read the same task shape).
TASK_RX='^### (Task ?|T)[0-9]+'

if [ "${1:-}" = "--brief" ]; then
  BRIEF_N="${2:-}"
  PLAN="${3:-}"
  CONTRACT="${4:-}"
  if [ -z "$BRIEF_N" ] || [ -z "$PLAN" ] || [ ! -f "$PLAN" ]; then
    echo "usage: plan-lint.sh --brief <N> <plan.md> [contract.md]" >&2
    exit 2
  fi
  if [ -n "$CONTRACT" ] && [ ! -f "$CONTRACT" ]; then
    echo "usage: plan-lint.sh --brief <N> <plan.md> [contract.md] — contract not found: $CONTRACT" >&2
    exit 2
  fi
  # shellcheck disable=SC2016
  BRIEF_AWK='
  function trim(x) { sub(/^[[:space:]]+/, "", x); sub(/[[:space:]]+$/, "", x); return x }
  function slug(x,   t, n, a, k, o, w) {
    t = tolower(x); gsub(/[^a-z0-9]+/, "-", t); gsub(/^-+|-+$/, "", t)
    n = split(t, a, "-"); o = ""
    for (k = 1; k <= n && split(o, w, "-") < 3; k++) {
      if (a[k] == "" || a[k] ~ /^(the|a|an|of|to|in|for|and|on|is|with)$/) continue
      o = (o == "") ? a[k] : o "-" a[k]
    }
    return (o == "") ? "task" : o
  }
  function addallowed(p) {
    if (p == "") return
    if (!(p in allowedset)) { allowedset[p] = 1; allowedord[++acnt] = p }
  }
  function rxesc(s,    out, i, c) {
    out = ""
    for (i = 1; i <= length(s); i++) {
      c = substr(s, i, 1)
      if (index("\\^$.[]|()*+?{}", c) > 0) out = out "\\" c
      else out = out c
    }
    return out
  }
  function is_prose(p,    n, parts, base, lp) {
    lp = tolower(p)
    if (lp ~ /\.(md|mdx|txt|rst|adoc)$/) return 1
    n = split(lp, parts, "/")
    base = parts[n]
    if (base ~ /^(readme|license|changelog)$/) return 1
    return 0
  }
  function is_security(p,    lp, n, w, i) {
    lp = tolower(p)
    gsub(/[^a-z0-9]/, " ", lp)
    n = split(lp, w, " ")
    for (i = 1; i <= n; i++)
      if (w[i] ~ /^(auth|authn|authz|billing|payment|payments|credit|credits|secret|secrets|token|tokens|crypto|migration|migrations|permission|permissions|webhook|webhooks|security|deletion)$/) return 1
    return 0
  }
  # A test file is named as a companion of the source it tests (Pythons
  # test_x.py, JS/TS x.test.ts / x.spec.ts, Go/Rust/Ruby/Elixir x_test.*) —
  # never a bare directory segment. A dir-based match would count a whole
  # integration/e2e suite (many concerns, one shared file) as "its own
  # test", masking a real multi-file change as R2.
  function is_test(p,    lp) {
    lp = tolower(p)
    if (lp ~ /\.(test|spec)\.[a-z0-9]+$/) return 1
    if (lp ~ /(^|\/)test_[^\/]+\.py$/) return 1
    if (lp ~ /(^|\/)conftest\.py$/) return 1
    if (lp ~ /_(test|spec)\.(go|rs|rb|ex|exs)$/) return 1
    return 0
  }
  # R2 < R3 < R4 — used to compare a task tier against the pool `tier =` line (spec R2).
  function tiernum(t) {
    if (t == "R2") return 2
    if (t == "R3") return 3
    return 4
  }
  # A field is only a line whose trimmed, asterisk-stripped start is a
  # bullet (dash OR asterisk — the same bullet grammar the Blocked-by /
  # Files / Owner graph scan below accepts), an optional checkbox
  # ([ ] / [x]), then the label -- never a prose sentence elsewhere on the
  # line that quotes the label (a Blocked by or Owner mention inside
  # Test / evidence prose must not be read as that field).
  function fieldline(line, name,    g) {
    g = line; sub(/^[[:space:]]+/, "", g)
    if (g !~ /^[-*]/) return 0
    g = substr(g, 2); gsub(/\*/, "", g); g = trim(g)
    return (g ~ ("^(\\[[ xX]\\][[:space:]]*)?" name ":"))
  }
  FNR == NR {
    if ($0 ~ /^## /) {
      intask = 0; field = ""
      specsec = ($0 ~ /^## Source spec/) ? 1 : 0
      filessec = ($0 ~ /^## Files to touch/) ? 1 : 0
      next
    }
    # A task heading also closes Source spec / Files to touch — some real
    # plans (e.g. the par-plan.md test fixture in this repo) go straight
    # from "## Files to touch" into "### Task 1" with no "## Tasks" line
    # between, so filessec must not still be open when the heading arrives.
    if ($0 ~ rx) {
      specsec = 0; filessec = 0
      id = $0; sub(/^### (Task ?|T)/, "", id); sub(/[^0-9].*$/, "", id)
      if (id == want) {
        intask = 1; found = 1
        title = $0
        sub(/^### (Task ?|T)[0-9]+/, "", title)
        sub(/^[^[:alnum:]]+/, "", title)
      } else intask = 0
      field = ""
      next
    }
    if (h1 == "" && $0 ~ /^# /) { h1 = $0; sub(/^# +/, "", h1) }
    if (specsec) { if (spec == "" && trim($0) != "") spec = trim($0); next }
    if (filessec) {
      m = $0
      while (match(m, /`[^`]+`/)) {
        p = substr(m, RSTART + 1, RLENGTH - 2)
        # a path has a slash, an extension, a Capitalised-then-lowercase bare
        # name (Makefile, Dockerfile) or is a well-known all-caps root file;
        # a backticked flag / symbol / identifier on the same line (`--all`,
        # `PHASE=x`, `KIND`) is commentary, never a forbidden path
        if ((p ~ /\// || p ~ /\.[A-Za-z][A-Za-z0-9]*$/ || p ~ /^[A-Z][a-z][A-Za-z0-9_-]*$/ || p ~ /^(README|LICENSE|CHANGELOG|CONTRIBUTING|AUTHORS|NOTICE|COPYING)$/) && !(p in touchseen)) { touchseen[p] = 1; touchorder[++tn] = p }
        m = substr(m, RSTART + RLENGTH)
      }
      next
    }
    if (intask) {
      line = $0
      isf = 1
      # Field labels match with or without **bold** — real plans write both
      # dialects (core/skills/write-plan/examples/plan-examples.md "Good"
      # scenario 1 is unbolded end to end). fieldline() requires the label
      # to START the (trimmed, unbolded) line, as a bullet — a prose
      # sentence that merely quotes the label text is never the field.
      if (fieldline(line, "Delivers"))             { field = "D";   v = line; sub(/^[[:space:]]*[-*][[:space:]]*(\[[ xX]\][[:space:]]*)?\*{0,2}Delivers\*{0,2}:\*{0,2}[[:space:]]*/, "", v) }
      else if (fieldline(line, "Blocked by"))      { field = "B";   v = line; sub(/^[[:space:]]*[-*][[:space:]]*(\[[ xX]\][[:space:]]*)?\*{0,2}Blocked by\*{0,2}:\*{0,2}[[:space:]]*/, "", v) }
      else if (fieldline(line, "Read first"))      { field = "R";   v = line; sub(/^[[:space:]]*[-*][[:space:]]*(\[[ xX]\][[:space:]]*)?\*{0,2}Read first\*{0,2}:\*{0,2}[[:space:]]*/, "", v) }
      else if (fieldline(line, "Files"))           { field = "F";   v = line; sub(/^[[:space:]]*[-*][[:space:]]*(\[[ xX]\][[:space:]]*)?\*{0,2}Files\*{0,2}:\*{0,2}[[:space:]]*/, "", v) }
      else if (fieldline(line, "Change"))          { field = "C";   v = line; sub(/^[[:space:]]*[-*][[:space:]]*(\[[ xX]\][[:space:]]*)?\*{0,2}Change\*{0,2}:\*{0,2}[[:space:]]*/, "", v) }
      else if (fieldline(line, "Test / evidence")) { field = "T";   v = line; sub(/^[[:space:]]*[-*][[:space:]]*(\[[ xX]\][[:space:]]*)?\*{0,2}Test \/ evidence\*{0,2}:\*{0,2}[[:space:]]*/, "", v) }
      else if (fieldline(line, "Command"))         { field = "Cmd"; v = line; sub(/^[[:space:]]*[-*][[:space:]]*(\[[ xX]\][[:space:]]*)?\*{0,2}Command\*{0,2}:\*{0,2}[[:space:]]*/, "", v) }
      # Optional — the narrowest command the build loop re-runs after every
      # edit, so the owner never falls back to the full Command per edit
      # (spec 2026-09-22: T3 owner spent 77% of tool time inside full-Command
      # single runs).
      else if (fieldline(line, "Check"))           { field = "Ck";  v = line; sub(/^[[:space:]]*[-*][[:space:]]*(\[[ xX]\][[:space:]]*)?\*{0,2}Check\*{0,2}:\*{0,2}[[:space:]]*/, "", v) }
      else if (fieldline(line, "Owner"))           { field = "O";   v = line; sub(/^[[:space:]]*[-*][[:space:]]*(\[[ xX]\][[:space:]]*)?\*{0,2}Owner\*{0,2}:\*{0,2}[[:space:]]*/, "", v) }
      else if (fieldline(line, "Done when"))       { field = "DW";  v = line; sub(/^[[:space:]]*[-*][[:space:]]*(\[[ xX]\][[:space:]]*)?\*{0,2}Done when\*{0,2}:\*{0,2}[[:space:]]*/, "", v) }
      # Optional — the one claim + command a reviewer would check by hand
      # (spec R3). A bullet of its own right after Test / evidence, never
      # indented under it (an indented line is a continuation, handled below).
      else if (fieldline(line, "Proof"))           { field = "P";   v = line; sub(/^[[:space:]]*[-*][[:space:]]*(\[[ xX]\][[:space:]]*)?\*{0,2}Proof\*{0,2}:\*{0,2}[[:space:]]*/, "", v) }
      # Recognized-but-not-in-the-brief fields still end whatever field came
      # before them — otherwise their text glues onto Test/Command/Done when.
      else if (fieldline(line, "Expected failing signal")) { field = "" }
      else if (fieldline(line, "On fail"))                 { field = "" }
      else isf = 0
      if (isf && field != "") {
        # Only the LEADING run of bold asterisks (the closing ** of a bold
        # label, e.g. "**Command:**") is stripped — a bare gsub also ate a
        # literal * inside the value itself, corrupting Command/Files text
        # like `pytest -k "test_brief*"` or `src/**/*.ts`.
        sub(/^\*+[[:space:]]*/, "", v); v = trim(v)
        if (field == "D") D = v
        else if (field == "B") B = v
        else if (field == "R") R = v
        else if (field == "F") Fr = v
        else if (field == "C") Ch = v
        else if (field == "T") Te = v
        else if (field == "Cmd") Cmd = v
        else if (field == "Ck") Ck = v
        else if (field == "O") Ow = v
        else if (field == "DW") DW = v
        else if (field == "P") Pr = v
      }
      # A continuation line extends the CURRENT field only when it is not
      # itself a new bullet — otherwise an unrecognized bullet (a field this
      # script does not track, or a typo) silently glues onto the last known
      # field instead of being dropped.
      # An INDENTED bullet is a sub-item of the current field (the template
      # allows a Change block of up to 3 bullets); only an unindented one is new.
      if (!isf && field != "" && trim(line) != "" && line !~ /^[-*][[:space:]]/) {
        cont = trim(line)
        if (field == "D") D = (D == "" ? cont : D "\n" cont)
        else if (field == "B") B = (B == "" ? cont : B "\n" cont)
        else if (field == "R") R = (R == "" ? cont : R "\n" cont)
        else if (field == "F") Fr = (Fr == "" ? cont : Fr "\n" cont)
        else if (field == "C") Ch = (Ch == "" ? cont : Ch "\n" cont)
        else if (field == "T") Te = (Te == "" ? cont : Te "\n" cont)
        else if (field == "Cmd") Cmd = (Cmd == "" ? cont : Cmd "\n" cont)
        else if (field == "Ck") Ck = (Ck == "" ? cont : Ck "\n" cont)
        else if (field == "O") Ow = (Ow == "" ? cont : Ow "\n" cont)
        else if (field == "DW") DW = (DW == "" ? cont : DW "\n" cont)
        else if (field == "P") Pr = (Pr == "" ? cont : Pr "\n" cont)
      }
      next
    }
    next
  }
  FNR != NR {
    if ($0 ~ /^## /) {
      ownsec = ($0 ~ /^## File ownership/) ? 1 : 0
      dnsec = ($0 ~ /^## Do-not-touch list/) ? 1 : 0
      next
    }
    if (ownsec) {
      if (match($0, /`[^`]+`/)) {
        label = substr($0, RSTART + 1, RLENGTH - 2)
        rest = substr($0, RSTART + RLENGTH)
        onum++
        ownlabel[onum] = label
        cnt = 0
        m = rest
        while (match(m, /`[^`]+`/)) {
          cnt++
          ownpath[onum, cnt] = substr(m, RSTART + 1, RLENGTH - 2)
          m = substr(m, RSTART + RLENGTH)
        }
        owncount[onum] = cnt
      }
      next
    }
    if (dnsec) {
      m = $0
      while (match(m, /`[^`]+`/)) {
        p = substr(m, RSTART + 1, RLENGTH - 2)
        if (!(p in dntset)) { dntset[p] = 1; dntord[++dn] = p }
        m = substr(m, RSTART + RLENGTH)
      }
      next
    }
    next
  }
  END {
    if (!found) {
      print "plan-lint --brief: Task " want " not found in " planpath > "/dev/stderr"
      exit 2
    }
    role = Ow
    sub(/\n.*/, "", role)
    sub(/[[:space:]]*\(.*/, "", role)
    sub(/[[:space:]]*·.*/, "", role)
    role = trim(role)
    low = tolower(Ow)
    write = "self"
    if (index(low, "write:") > 0 && index(low, "external") > 0) write = "external"
    m = Fr
    while (match(m, /`[^`]+`/)) {
      p = substr(m, RSTART + 1, RLENGTH - 2)
      addallowed(p)
      m = substr(m, RSTART + RLENGTH)
    }
    restv = Fr
    gsub(/`[^`]+`/, " ", restv)
    ntok = split(restv, toks, /[,[:space:]]+/)
    for (ti = 1; ti <= ntok; ti++) {
      tok = toks[ti]
      gsub(/[,;)]+$/, "", tok)
      if (tok == "" || tok ~ /^</) continue
      if (tok ~ /^([Aa]nd|[Oo]r)$/) continue
      if (tok ~ /\// || tok ~ /\.[[:alnum:]]+$/) addallowed(tok)
    }
    if (hascontract) {
      # Pass 1: a `T<N>` / `Task N` tag on a label names THIS task
      # unambiguously — when any label carries one, that is the whole
      # answer and the (weaker) role-name match is not consulted at all.
      # Otherwise two labels for the same role but different tasks, e.g.
      # `backend-developer (T1)` and `backend-developer (T4)`, would both
      # match Task 1 by role name and leak the T4 files into the T1 brief.
      tagfound = 0
      tpat = "(^|[^0-9A-Za-z])T" want "([^0-9A-Za-z]|$)"
      tpat2 = "(^|[^0-9A-Za-z])Task[[:space:]]+" want "([^0-9A-Za-z]|$)"
      for (k = 1; k <= onum; k++) {
        tagmatch[k] = (ownlabel[k] ~ tpat) || (ownlabel[k] ~ tpat2)
        if (tagmatch[k]) tagfound = 1
      }
      for (k = 1; k <= onum; k++) {
        ml = 0
        if (tagfound) {
          ml = tagmatch[k]
        } else if (role != "") {
          # Role match is boundary-anchored — a plain substring let
          # "backend-developer" match a label naming a DIFFERENT task.
          # The boundary excludes hyphen (part of a kebab-case role token).
          rolepat = "(^|[^A-Za-z0-9-])" rxesc(role) "([^A-Za-z0-9-]|$)"
          if (ownlabel[k] ~ rolepat) ml = 1
        }
        if (ml) for (pi = 1; pi <= owncount[k]; pi++) addallowed(ownpath[k, pi])
      }
    }
    printf "# Task %s: %s\n", want, trim(title)
    specout = (spec == "") ? "(not in plan)" : spec
    printf "Plan: %s · Spec: %s\n", planpath, specout
    feat = h1; sub(/[[:space:]]+[Pp]lan[[:space:]]*$/, "", feat); feat = slug(feat)
    tslug = slug(title)
    print "## Worktree"
    printf "`git worktree add -b %s/t%s-%s ../%s-wt-%s-t%s-%s` — cd there for every command; the name says which task it holds\n", feat, want, tslug, repo, feat, want, tslug
    print "## Goal"
    print (D == "" ? "(not in plan)" : D)
    print "## Tier"
    # Computed ONCE here and reused by ## Reviewers below — Reviewers
    # follows the tier (spec R2), it never re-derives it from the raw
    # helpers, so the two can never print a mismatched pair on a reorder.
    tprose = 1
    for (i = 1; i <= acnt; i++) if (!is_prose(allowedord[i])) tprose = 0
    # The repo risk-paths override (same file the commit gate reads): a bare / +
    # line adds a path pattern, a - line excludes one. Case-insensitive, like the gate.
    radd = tolower(ENVIRON["RP_RISK_ADD"]); rexcl = tolower(ENVIRON["RP_RISK_EXCL"])
    trisk = 0
    for (i = 1; i <= acnt; i++) {
      lp = tolower(allowedord[i])
      hit = is_security(allowedord[i])
      if (radd != "" && lp ~ radd) hit = 1
      if (hit && rexcl != "" && lp ~ rexcl) hit = 0
      if (hit) trisk = 1
    }
    tnontest = 0
    for (i = 1; i <= acnt; i++) if (!is_test(allowedord[i])) tnontest++
    if (acnt > 0 && tprose) tier = "R1"
    else if (trisk) tier = "R4"
    else if (tnontest == 1 && (acnt - tnontest) <= 1) tier = "R2"
    else tier = "R3"
    tiergloss["R1"] = "R1 (docs-only)"; tiergloss["R2"] = "R2 (one file + test)"
    tiergloss["R3"] = "R3 (multi-file)"; tiergloss["R4"] = "R4 (high-risk)"
    print tiergloss[tier]
    print "## Blocked by"
    print (B == "" ? "(not in plan)" : B)
    print "## Read first"
    print (R == "" ? "(Lead: 2-3 files + the pattern to copy — the owner never re-surveys the repo)" : R)
    print "## Files allowed"
    if (acnt == 0) print "(not in plan)"
    else for (i = 1; i <= acnt; i++) print "- " allowedord[i]
    print "## Files forbidden"
    for (i = 1; i <= tn; i++) { p = touchorder[i]; if (!(p in allowedset)) print "- " p }
    # Guarded against Files allowed the same way the touch-list loop above
    # is (a do-not-touch path that also landed in Files allowed must not
    # print twice or contradict the allowed list), AND against touchseen —
    # a path already printed by the touch-list loop above must not print a
    # second time just because it is ALSO on the do-not-touch list.
    if (hascontract) for (i = 1; i <= dn; i++) { p = dntord[i]; if (!(p in allowedset) && !(p in touchseen)) print "- " p }
    print "- everything else (an unowned path: touch it and add an Also touched line; a path another owner holds: a NEEDS line, never an edit)"
    print "## Change"
    print (Ch == "" ? "(not in plan)" : Ch)
    print "## Test / evidence"
    print (Te == "" ? "(not in plan)" : Te)
    print "## Command"
    print (Cmd == "" ? "(not in plan)" : Cmd)
    print "## Check"
    # A value opening with "<" is an undeleted template placeholder — same
    # convention as the Proof placeholder skip below — treated as absent.
    if (Ck == "" || Ck ~ /^`?</) print "none — pick the narrowest command that covers each edit (one case file, one test name, one module)"
    else print Ck
    print "Test levels — each runs at ONE point, never at the one above it:"
    print "1. Check   — the narrowest command covering the edit; the owner runs it after every edit."
    print "2. Command — the task suite; runs ONCE at integration, not by the owner."
    print "3. Release — the whole-repo suite; runs ONCE per release, by the Lead."
    print "## Proof"
    # An undeleted template placeholder ("<the one claim...> :: `<the command
    # that proves it>`") is not a real Proof — same convention as the bare-path
    # token skip above (a value opening with "<" is a hint, never printed).
    if (Pr == "" || Pr ~ /^</) print "none"
    else {
      # Split on the FIRST " :: " only — a claim never contains that token,
      # and the command (kept exactly as written, backticks included) may
      # itself hold a pipe or a quoted string that must survive byte-for-byte.
      psep = index(Pr, " :: ")
      if (psep > 0) {
        pclaim = trim(substr(Pr, 1, psep - 1))
        pcmd = trim(substr(Pr, psep + 4))
      } else {
        pclaim = trim(Pr)
        pcmd = ""
      }
      print pclaim
      if (pcmd != "") print pcmd
    }
    print "## Done when"
    print (DW == "" ? "(not in plan)" : DW)
    print "## Write"
    printf "`%s`\n", write
    print "## Reviewers"
    if (tier == "R1") print "`none`"
    else {
      if (tier == "R4") r = "`universal-reviewer` (internal strong) or, with a usable pool, `rolepod-cross-family --kind review --brief <this brief> --attach <diff> --detach` instead, plus `security-engineer`"
      else {
        poolt = ENVIRON["RP_REVIEW_TIER"]
        if (poolt == "") poolt = "R4"
        # spec D1/D2: an R2/R3 task at or above the pool tier gets the same
        # external-alternative clause the R4 line carries above.
        if ((poolt == "R2" || poolt == "R3") && tiernum(tier) >= tiernum(poolt)) r = "`universal-reviewer` or, with a usable pool, `rolepod-cross-family --kind review --brief <this brief> --attach <diff> --detach` instead"
        else r = "`universal-reviewer`"
      }
      if (Te ~ /(E2E|e2e|[Ee]nd-to-end|browser|screenshot|uiproof|UI test|UI flow|user-visible|Playwright|Cypress|visual diff)/) r = r ", `qa-tester` (E2E)"
      print r
      # The round shape lives HERE, where the owner picks its reviewers: at the
      # end of the Bounds line two owners in a row still messaged the finished
      # reviewer for round 2 and idled while the answer landed at the Lead.
      print "Round 2 = ONE new foreground dispatch of the flagging reviewer on the fix delta, never a message to the finished one (a sub-agent gets no reply to it; the answer lands at the Lead). Max 2 rounds. The round-2 prompt carries the findings and the fix delta only, never a new run, mutant or suite: round 1 proof is not redone."
    }
    print "## Bounds"
    printf "- Edit only Files allowed, and only under ../%s-wt-%s-t%s-%s — the same path in the main checkout belongs to the Lead; no backup copies (.bak / .orig). Never commit or push; leave the tree staged.\n", repo, feat, want, tslug
    print "- Run the Command in the foreground (Bash timeout 600000; never run_in_background - nothing wakes a sub-agent); a code diff → dispatch the Reviewers in ONE message (reports to .rolepod/evidence/review/<task>-<role>.md); fix; then the Reviewers section above."
    print "- Budget: build <= 40 tool calls, whole loop <= 120; past it return PARTIAL with what is done, never grind."
    print "- Return a decision brief: verdict, `git diff --cached --stat | tail -3`, Command last 3 lines verbatim, reviewer verdicts + report paths, residuals."
  }
  '
  BRIEF_ROOT="$(git -C "$(dirname "$PLAN")" rev-parse --show-toplevel 2>/dev/null || pwd)"
  BRIEF_REPO="$(basename "$BRIEF_ROOT")"
  # <git-root>/.rolepod/risk-paths — parsed exactly like precommit-gate.sh risk_filter.
  RP_RISK_ADD=""; RP_RISK_EXCL=""
  if [ -f "$BRIEF_ROOT/.rolepod/risk-paths" ]; then
    RP_RISK_ADD=$(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' -e '/^-/d' -e 's/^+//' "$BRIEF_ROOT/.rolepod/risk-paths" 2>/dev/null | paste -sd'|' - 2>/dev/null || true)
    RP_RISK_EXCL=$(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$BRIEF_ROOT/.rolepod/risk-paths" 2>/dev/null | grep '^-' 2>/dev/null | sed 's/^-//' | paste -sd'|' - 2>/dev/null || true)
  fi
  # Fail open like the gate: a pattern awk cannot compile is dropped (built-ins only),
  # never a brief cut off mid-way. Probed with awk itself — grep -E accepts a different set.
  rp_ere_ok() { printf 'x\n' | RP_P="$1" awk '{ if ($0 ~ tolower(ENVIRON["RP_P"])) n = 1 }' >/dev/null 2>&1; }
  [ -z "$RP_RISK_ADD" ] || rp_ere_ok "$RP_RISK_ADD" || RP_RISK_ADD=""
  [ -z "$RP_RISK_EXCL" ] || rp_ere_ok "$RP_RISK_EXCL" || RP_RISK_EXCL=""
  export RP_RISK_ADD RP_RISK_EXCL
  # Effective cross-family review tier (spec D1/D2) — resolved ONCE here and
  # reused by ## Reviewers above, so the two can never print a mismatched
  # pair. The runner beside this script wins (the shipped one), else the
  # installed launcher; anything else (no runner, no pool, no line) → R4,
  # which is today's behaviour untouched.
  XFAM_RUNNER="$(dirname "$0")/cross-family.sh"
  [ -f "$XFAM_RUNNER" ] || XFAM_RUNNER="$HOME/.rolepod/bin/cross-family.sh"
  RP_REVIEW_TIER="R4"
  if [ -f "$XFAM_RUNNER" ]; then
    _rt="$(bash "$XFAM_RUNNER" --review-tier --root "$BRIEF_ROOT" 2>/dev/null)"
    case "$_rt" in R2|R3|R4) RP_REVIEW_TIER="$_rt" ;; esac
  fi
  export RP_REVIEW_TIER
  if [ -n "$CONTRACT" ]; then
    awk -v rx="$TASK_RX" -v want="$BRIEF_N" -v planpath="$PLAN" -v repo="$BRIEF_REPO" -v hascontract=1 "$BRIEF_AWK" "$PLAN" "$CONTRACT"
  else
    awk -v rx="$TASK_RX" -v want="$BRIEF_N" -v planpath="$PLAN" -v repo="$BRIEF_REPO" -v hascontract=0 "$BRIEF_AWK" "$PLAN"
  fi
  exit $?
fi

PLAN="${1:-}"
CONTRACT="${2:-}"

if [ -z "$PLAN" ] || [ ! -f "$PLAN" ]; then
  echo "usage: plan-lint.sh <plan.md> [contract.md]" >&2
  exit 2
fi

fail=0

# ── 1. Failure policy ────────────────────────────────────────────────────
if grep -q '^## Failure policy' "$PLAN"; then
  echo "  ✓ Failure policy present"
else
  echo "  ✗ missing '## Failure policy' — the build loop has no circuit breaker"
  fail=1
fi

# ── 2. Command per task ──────────────────────────────────────────────────
# Walk each task block on its own — an aggregate count let one task's
# extra Commands cover for a sibling with none, and 0 tasks passed 0 >= 0.
# 'Command:' still counts only inside task blocks (never Failure-policy prose).
# Heading shapes: `### Task 1:` (template) and `### T1 —` (a real CourtBook
# plan, which this lint rejected wholesale before v2.90.0). TASK_RX is set
# at the top of the file — shared with --brief, not re-declared here.
TASKS=$(grep -Ec "$TASK_RX" "$PLAN" || true)
MISSING=$(awk -v rx="$TASK_RX" '
  function trim(x) { sub(/^[[:space:]]+/, "", x); sub(/[[:space:]]+$/, "", x); return x }
  # A field is only a line whose (left-trimmed) start is a bullet — dash OR
  # asterisk — an optional checkbox, then the label. The bullet char is
  # consumed BEFORE bold asterisks are stripped: a whole-line gsub(/\*/)
  # first would eat an asterisk BULLET along with the bold markers, making
  # a "* Command:" line unreachable — and would also let a prose sentence
  # elsewhere on the line that merely quotes "Command:" pass the check.
  function fieldgate(line, name,    g) {
    g = line; sub(/^[[:space:]]+/, "", g)
    if (g !~ /^[-*]/) return 0
    g = substr(g, 2); gsub(/\*/, "", g); g = trim(g)
    return (g ~ ("^(\\[[ xX]\\][[:space:]]*)?" name ":"))
  }
  $0 ~ rx     { if (t != "" && !c) print t; t = $0; c = 0; next }
  /^## /      { if (t != "" && !c) print t; t = ""; next }
  t != "" && fieldgate($0, "Command") { c = 1 }
  END         { if (t != "" && !c) print t }
' "$PLAN")
if [ "${TASKS:-0}" -eq 0 ]; then
  echo "  ✗ no task blocks found (### Task N: / ### TN —) — nothing for the build loop to run"
  fail=1
elif [ -z "$MISSING" ]; then
  echo "  ✓ every task carries a Command ($TASKS/$TASKS)"
else
  while IFS= read -r t; do
    [ -n "$t" ] && echo "  ✗ missing Command: ${t#\#\#\# } — a Command-less task cannot be verified by the loop"
  done <<EOF
$MISSING
EOF
  fail=1
fi

# Parallel layout is read once here — the graph check below needs to know
# whether Sequential was CHOSEN (then extra roots are an advisory, not a
# mistake), and the ownership check needs the contract path.
# Anchored to a line START (optional bullet) — a bare substring grep let
# 'Not sequential — two tracks run concurrently' skip the ownership check.
LAYOUT=$(awk '/^## Parallel layout/{f=1;next} /^## /{f=0} f' "$PLAN")
SEQUENTIAL=0
printf '%s' "$LAYOUT" | grep -qiE '^[[:space:]]*([-*][[:space:]]*)?sequential' && SEQUENTIAL=1

# ── 3. Blocked-by graph ──────────────────────────────────────────────────
# One awk pass: task id from the heading, refs from the `Blocked by:` line
# (integers after the colon; "none" / "—" / "-" = no blockers). Then resolve
# every ref, count fields, and run Kahn's algorithm for a cycle. Output lines
# are prefixed so the shell can route them: E = fail, A = advisory.
GRAPH=$(awk -v rx="$TASK_RX" -v seq="$SEQUENTIAL" '
  function trim(x) { sub(/^[[:space:]]+/, "", x); sub(/[[:space:]]+$/, "", x); return x }
  # A field is only a line whose (left-trimmed) start is a bullet — dash OR
  # asterisk — an optional checkbox, then the label. The bullet char must be
  # consumed BEFORE bold asterisks are stripped: gsub(/\*/,"") on the whole
  # line first would eat an asterisk BULLET along with the bold markers,
  # making a "* Label:" line unreachable.
  function fieldgate(line, name,    g) {
    g = line; sub(/^[[:space:]]+/, "", g)
    if (g !~ /^[-*]/) return 0
    g = substr(g, 2); gsub(/\*/, "", g); g = trim(g)
    return (g ~ ("^(\\[[ xX]\\][[:space:]]*)?" name ":"))
  }
  function addpath(p, c) {
    if (!((p, c) in pathseen)) {
      if (!(p in pathtasks)) pathorder[++pn] = p
      pathtasks[p] = pathtasks[p] " " c
      pathseen[p, c] = 1
    }
  }
  $0 ~ rx {
    id = $0; sub(/^### (Task ?|T)/, "", id); sub(/[^0-9].*$/, "", id)
    if (id in seen) dup[id] = 1
    cur = id; n++; order[n] = id; seen[id] = 1; next
  }
  /^## / { cur = "" ; next }
  cur != "" && /Blocked by:/ && !(cur in has) {
    # A field is only a line whose trimmed start is the label (with or
    # without a leading dash / checkbox bullet and bold markers) --
    # a prose sentence elsewhere on the line that merely quotes the
    # label text is never the field.
    if (!fieldgate($0, "Blocked by")) next
    has[cur] = 1; vt = $0; gsub(/\*/, "", vt); vt = trim(vt); sub(/^[-*][[:space:]]*/, "", vt); v = vt
    sub(/^(\[[ xX]\][[:space:]]*)?Blocked by:[[:space:]]*/, "", v); v = trim(v)
    # lowercased before the check — the same tolower() approach ticket.sh
    # uses, so "NONE" (any casing) means no blockers on both parsers, not
    # just "None"/"none".
    if (tolower(v) ~ /^(none|—|-|–)/) next
    # strip every parenthesised aside individually — "Task 1 (why), Task 3
    # (why), Task 4 (why)" must resolve to {1,3,4}, not just the first ref.
    gsub(/\([^)]*\)/, "", v)
    # then a trailing em/en-dash aside (no parens) — "Task 3 — landed in
    # v2.90.0" must resolve to {3}, not pick up 2/90/0 out of the prose.
    sub(/[[:space:]]+(—|–)[[:space:]]+.*$/, "", v)
    m = v
    while (match(m, /[0-9]+/)) {
      r = substr(m, RSTART, RLENGTH); m = substr(m, RSTART + RLENGTH)
      if (!(cur SUBSEP r in edge)) { edge[cur, r] = 1; refs[cur] = refs[cur] " " r }
    }
    next
  }
  # Advisory (v2.144.0) inputs, gathered off the SAME task blocks: every
  # path on a task first "Files:" line (bold or not — a prefactor-smell
  # candidate needs no more than the path and the task ids), backticked OR
  # bare (real plans, incl. the template + examples, write Files as a plain
  # comma-separated list — a backtick-only parse was a no-op on them), and
  # each task first "Owner:" value (for the nothing-to-dispatch check).
  cur != "" && /Files:/ && !(cur in filesdone) {
    # Gate via fieldgate() (bullet consumed before bold strip) — the
    # extracted value below keeps the raw line so a glob like
    # `src/**/*.ts` is untouched.
    if (!fieldgate($0, "Files")) next
    filesdone[cur] = 1
    v = $0; sub(/^[[:space:]]*[-*][[:space:]]*(\[[ xX]\][[:space:]]*)?\*{0,2}Files\*{0,2}:\*{0,2}[[:space:]]*/, "", v)
    m = v
    while (match(m, /`[^`]+`/)) {
      addpath(substr(m, RSTART + 1, RLENGTH - 2), cur)
      m = substr(m, RSTART + RLENGTH)
    }
    # Bare tokens: strip out what was already claimed as backticked, split
    # the rest on commas/whitespace, then keep only path-shaped tokens —
    # contains a slash, or ends in a dot + an alnum extension.
    # Placeholders ("<paths...>") and filler words ("and"/"or") are dropped.
    rest = v
    gsub(/`[^`]+`/, " ", rest)
    ntok = split(rest, toks, /[,[:space:]]+/)
    for (ti = 1; ti <= ntok; ti++) {
      tok = toks[ti]
      gsub(/[,;)]+$/, "", tok)
      if (tok == "" || tok ~ /^</) continue
      if (tok ~ /^([Aa]nd|[Oo]r)$/) continue
      if (tok ~ /\// || tok ~ /\.[[:alnum:]]+$/) addpath(tok, cur)
    }
    next
  }
  cur != "" && /Owner:/ && !(cur in ownerdone) {
    if (!fieldgate($0, "Owner")) next
    ownerdone[cur] = 1; v = $0
    sub(/^[[:space:]]*[-*][[:space:]]*(\[[ xX]\][[:space:]]*)?\*{0,2}Owner\*{0,2}:\*{0,2}[[:space:]]*/, "", v); gsub(/\*/, "", v); v = trim(v)
    owner[cur] = v
    next
  }
  END {
    if (n == 0) exit 0
    for (d in dup) print "E duplicate task id " d " — two blocks carry the same number; Blocked by cannot name either"
    withf = 0; for (k = 1; k <= n; k++) if (order[k] in has) withf++
    if (withf == 0) print "A no Blocked by fields — order is prose only; add one per task"
    # The graph-resolution block below (missing-field / unresolved-ref /
    # cycle checks) needs at least one Blocked by field to mean anything —
    # skipped (not exited) when withf == 0, so the two advisories further
    # down (neither depends on this graph resolving) still run on a legacy
    # plan that never uses Blocked by at all.
    if (withf > 0) {
    for (k = 1; k <= n; k++) if (!(order[k] in has)) print "E Task " order[k] " has no Blocked by (other tasks do) — state its blockers or none"
    # Resolve refs only now — a blocker may be declared later in the file.
    # An unresolved or self ref is reported and dropped from the graph, so
    # it cannot masquerade as a cycle below.
    for (k = 1; k <= n; k++) {
      t = order[k]; split(refs[t], rs, " ")
      for (j in rs) { r = rs[j]; if (r == "") continue
        if (!(r in seen)) { print "E Task " t " is blocked by Task " r " — no such task in this plan"; edge[t, r] = 0 }
        else if (r == t)  { print "E Task " t " blocks itself"; edge[t, r] = 0 }
        else { indeg[t]++; nxt[r] = nxt[r] " " t }
      }
    }
    # Kahn: indeg = number of RESOLVED blockers; peel roots
    done = 0; roots = ""
    for (k = 1; k <= n; k++) { t = order[k]; if (indeg[t] + 0 == 0) { q[++qt] = t; roots = roots (roots == "" ? "" : ", ") t } }
    while (qh < qt) { t = q[++qh]; done++
      for (k = 1; k <= n; k++) { u = order[k]; if ((u, t) in edge) { edge[u, t] = 0; indeg[u]--; if (indeg[u] == 0) q[++qt] = u } } }
    if (done < n) { c = ""; for (k = 1; k <= n; k++) if (indeg[order[k]] > 0) c = c (c == "" ? "" : ", ") order[k]
      if (c != "") print "E Blocked-by cycle among Tasks " c " — nothing can start" }
    else if (seq && qt > 0 && index(roots, ",")) print "A parallel candidates: Tasks " roots " have no blockers — Sequential chosen, fine if the layout line says why"
    }
    # ── Advisory (v2.144.0a): prefactor smell ─────────────────────────────
    # Two tasks sharing a Files path with no dependency path between them,
    # either way, in the (already-resolved) Blocked-by graph. Reuses nxt[]
    # (built above alongside indeg[]) for a per-task BFS reachability set —
    # vis[t, w] means w is reachable from t, i.e. t blocks w transitively.
    for (k = 1; k <= n; k++) {
      t = order[k]; qh2 = 0; qt2 = 0
      qt2++; q2[qt2] = t; vis[t, t] = 1
      while (qh2 < qt2) {
        qh2++; u = q2[qh2]
        split(nxt[u], kids, " ")
        for (ki in kids) {
          w = kids[ki]; if (w == "") continue
          if (!((t, w) in vis)) { vis[t, w] = 1; qt2++; q2[qt2] = w }
        }
      }
    }
    for (pi = 1; pi <= pn; pi++) {
      p = pathorder[pi]; np = split(pathtasks[p], ids, " ")
      for (i = 1; i <= np; i++) for (j = i + 1; j <= np; j++) {
        a = ids[i]; b = ids[j]
        if (a + 0 > b + 0) { tmp = a; a = b; b = tmp }
        if (!((a, b) in vis) && !((b, a) in vis))
          print "F ⚠ prefactor smell: `" p "` in Task " a " and Task " b " with no edge — extract a module first, or make one block the other"
      }
    }
    # ── Advisory (v2.144.0b): nothing to dispatch ─────────────────────────
    # Every task Owner: line names Lead (plain "Lead", "Lead (…)", or a
    # role annotated "(Lead self-do)") on a plan big enough to route.
    if (n >= 3) {
      all_lead = 1
      for (k = 1; k <= n; k++) {
        t = order[k]
        if (!(t in ownerdone)) { all_lead = 0; continue }
        ov = owner[t]
        lead = (ov ~ /^Lead$/) || (ov ~ /^Lead[[:space:](]/) || (ov ~ /\(Lead self-do\)/)
        if (!lead) all_lead = 0
      }
      if (all_lead) print "O ⚠ every Owner is Lead (" n " tasks) — nothing to dispatch; from R3 up the Owner map decides"
    }
  }
' "$PLAN")
GRAPH_E=$(printf '%s\n' "$GRAPH" | grep '^E ' || true)
GRAPH_A=$(printf '%s\n' "$GRAPH" | grep '^A ' || true)
if [ -n "$GRAPH_E" ]; then
  printf '%s\n' "$GRAPH_E" | sed 's/^E /  ✗ /'
  fail=1
elif [ "${TASKS:-0}" -gt 0 ] && [ -z "$GRAPH_A" ]; then
  echo "  ✓ Blocked-by graph resolves, no cycle ($TASKS tasks)"
elif [ -n "$GRAPH_A" ] && ! printf '%s' "$GRAPH_A" | grep -q 'no Blocked by fields'; then
  echo "  ✓ Blocked-by graph resolves, no cycle ($TASKS tasks)"
fi
[ -n "$GRAPH_A" ] && printf '%s\n' "$GRAPH_A" | sed 's/^A /  · /'

# ── Advisories (v2.144.0) — never fail; a Sequential plan may be legitimate.
GRAPH_F=$(printf '%s\n' "$GRAPH" | grep '^F ' || true)
GRAPH_O=$(printf '%s\n' "$GRAPH" | grep '^O ' || true)
[ -n "$GRAPH_F" ] && printf '%s\n' "$GRAPH_F" | sed 's/^F /  /'
[ -n "$GRAPH_O" ] && printf '%s\n' "$GRAPH_O" | sed 's/^O /  /'

# ── 4. Parallel ownership completeness ───────────────────────────────────
if [ "$SEQUENTIAL" -eq 1 ]; then
  echo "  ✓ sequential layout — ownership check not applicable"
  echo "plan-lint: $([ "$fail" -eq 0 ] && echo PASS || echo FAIL)"
  exit "$fail"
fi

# Resolve the contract file.
if [ -z "$CONTRACT" ]; then
  REL=$(printf '%s' "$LAYOUT" | grep -oE '`[^`]+\.md`' | head -1 | tr -d '`')
  if [ -n "$REL" ]; then
    PLAN_DIR="$(cd "$(dirname "$PLAN")" && pwd)"
    ROOT="$(git -C "$PLAN_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$PLAN_DIR")"
    for cand in "$PLAN_DIR/$REL" "$ROOT/$REL" "$REL"; do
      [ -f "$cand" ] && CONTRACT="$cand" && break
    done
  fi
fi

if [ -z "$CONTRACT" ] || [ ! -f "$CONTRACT" ]; then
  if [ -n "$LAYOUT" ]; then
    echo "  ✗ parallel layout declared but no cohesion contract found — Iron Rule 2: no parallel agents without a contract"
    fail=1
  else
    echo "  ✗ no '## Parallel layout' section — declare 'Sequential — single owner.' or the contract path"
    fail=1
  fi
  echo "plan-lint: FAIL"
  exit 1
fi

OWNERSHIP=$(awk '/^## File ownership/{f=1;next} /^## /{f=0} f' "$CONTRACT")
if [ -z "$OWNERSHIP" ]; then
  echo "  ✗ contract has no '## File ownership' section"
  echo "plan-lint: FAIL"
  exit 1
fi

# Every backticked path in the plan's Files-to-touch must appear under
# exactly one owner line.
FILES=$(awk '/^## Files to touch/{f=1;next} /^## /{f=0} f' "$PLAN" \
        | grep -oE '`[^`]+`' | tr -d '`' | sort -u)
if [ -z "$FILES" ]; then
  echo "  ✗ parallel plan has no backticked paths under '## Files to touch'"
  fail=1
fi

OWN_OK=1
while IFS= read -r f; do
  [ -n "$f" ] || continue
  # Count OWNER LINES that mention the exact backticked path.
  N=$(printf '%s\n' "$OWNERSHIP" | grep -cF "\`$f\`" || true)
  if [ "${N:-0}" -eq 0 ]; then
    echo "  ✗ unowned file: \`$f\` — in Files-to-touch but under no owner in the contract"
    OWN_OK=0; fail=1
  elif [ "${N:-0}" -gt 1 ]; then
    echo "  ✗ dual-owned file: \`$f\` — appears under $N owner lines; a path belongs to exactly one owner"
    OWN_OK=0; fail=1
  fi
done <<EOF
$FILES
EOF
[ "$OWN_OK" -eq 1 ] && [ -n "$FILES" ] && echo "  ✓ every touched file has exactly one owner"

echo "plan-lint: $([ "$fail" -eq 0 ] && echo PASS || echo FAIL)"
exit "$fail"
