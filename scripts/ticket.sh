#!/bin/bash
# rolepod-ticket — deterministic ticket-loop helper (spec: lead-cost-no-pause
# 2026-09-22, architecture A). Moves the Lead's per-task mechanics (worktree,
# spot-check, bookkeeping) into one CLI-neutral tool so a ticket loop costs
# the Lead a handful of calls instead of ~35.
#
# Usage:
#   rolepod-ticket start <plan> <N> [--base <branch>]
#     plan-lint the plan (FAIL stops here), write Task N's brief to
#     docs/rolepod/handoffs/<plan-slug>-tN-owner.md, create the worktree +
#     branch the brief's own "## Worktree" line names (off <base>, default
#     the current branch), print "<brief-path> <worktree-path>" then a
#     second line "agent: <name>" (the name recorded in the brief's own
#     "Agent:" line, for `finish` to report back later), then a third line
#     "ship: <the commit -> finish -> log chain>" for the Lead to paste once
#     the task is done.
#     Re-running against an existing worktree reprints the same three lines
#     and changes nothing else.
#
#   rolepod-ticket integrate <worktree> --brief <file> [--pre '<cmd>'] [--gate '<cmd>']
#     Refuses an ambiguous worktree (unmerged commits + a dirty tree).
#     Runs --pre, ff-merges the base into the worktree branch, stages
#     everything except docs/rolepod/, then runs the brief's Proof command
#     (if any) and --gate — one "ok" or a <=15-line failing tail per step,
#     first failure exits non-zero (the owner already ran the brief's
#     Command; integrate never re-runs it). On success prints the cached
#     diff stat, any reviewer verdict newer than the worktree, and the same
#     ship chain `start` printed, from `git -C <worktree> commit` on. Never
#     commits itself.
#
#   rolepod-ticket finish <worktree>
#     Refuses a dirty worktree or one whose branch cannot ff-merge (base is
#     not an ancestor of its HEAD — nothing safely mergeable). Otherwise
#     ff-merges the branch into the base checkout, removes + prunes the
#     worktree, deletes the branch, prints "close: <agent name or (unrecorded)>".
#
#   rolepod-ticket log <plan> <N> --sha <sha> --note '<text>'
#     Flips every `- [ ]` inside Task N's block to `- [x]` and appends one
#     bullet under "## Changes during build". The only writer of the plan
#     file besides the Lead's own editor. Then names every not-done task
#     whose Blocked-by list names N and is now fully done ("ready now: Task
#     a (<owner>), ..."), plus "fleet: rolepod-ticket fleet <plan>" when one
#     of them is role-owned. Once every role-owned task is done, also prints
#     "review: <first logged task sha>^..HEAD — one combined review before
#     release (implement-plan Review)", and writes that same range (generated
#     files left out) to .rolepod/evidence/review/<plan-slug>.diff, naming
#     it on the same line ("; lens diff: <path>") so the review lenses get
#     the diff as a file, not a shell. A write failure never fails log — the
#     range still prints, just without the path. Idempotent, same as the
#     checkbox flip.
#
#   rolepod-ticket fleet <plan> [--base <branch>] [--max <N>] [--gate '<cmd>']
#     On the one CLI with a workflow tool: for every task whose Blocked-by
#     tasks are all done and whose Owner is a role (not Lead), runs `start`
#     and reads its brief's "## Reviewers" line, then prints ONE JSON object
#     {scriptPath, args} for scripts/ticket-fleet.js (args.tasks =
#     [{n, brief, worktree, role, reviewers}]) plus one line on how to
#     launch it. No ready role-owned task: says so, exit 0.
#     --gate '<cmd>' runs once in the checkout fleet was called from, before
#     any start; a non-zero exit prints its tail and refuses with no
#     worktree created at all.
#     A ready task whose worktree already exists (an earlier fleet/start
#     already launched it) is skipped as "in flight", left out of the JSON,
#     and never re-started.
#     --max <N> keeps only the first N still-not-in-flight tasks in plan
#     order and holds the rest back by name, deciding before `start` is
#     ever called so a held-back task never gets a worktree.
#
# `start` and `fleet` hold a per-plan lock (<git-common-dir>/rolepod-ticket-
# <plan-slug>.lock) for their run: a second one on the same plan refuses until
# the first ends; a lock whose process is gone is taken over.
#
# bash 3.2 safe, set -u safe, no network, fail-closed with one-line errors.
set -uo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
LINT="$SELF_DIR/plan-lint.sh"
[ -f "$LINT" ] || LINT="$HOME/.rolepod/bin/plan-lint.sh"

# plan_task_rows' internal field separator (fleet only) — never a tab: `read`
# treats tab as "IFS whitespace" regardless of what IFS is set to, so it
# COLLAPSES adjacent tabs instead of yielding an empty field for a task with
# no Blocked-by, silently shifting every field after it.
ROW_FS=$'\x1f'

usage() {
  cat <<'EOF'
usage:
  rolepod-ticket start <plan> <N> [--base <branch>]
  rolepod-ticket integrate <worktree> --brief <file> [--pre '<cmd>'] [--gate '<cmd>']
  rolepod-ticket finish <worktree>
  rolepod-ticket log <plan> <N> --sha <sha> --note '<text>'
  rolepod-ticket fleet <plan> [--base <branch>] [--max <N>] [--gate '<cmd>']
EOF
}

# ── helpers ──────────────────────────────────────────────────────────────

# The main (first-listed) worktree of the repo $1 belongs to — resolvable
# from any linked worktree since worktrees share one ref database.
main_root_of() {
  git -C "$1" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}'
}

# Lines of section "$2" (an exact "## Heading" string) inside file "$1".
section_body() {
  awk -v h="$2" '
    $0 == h { f = 1; next }
    /^## / { f = 0 }
    f { print }
  ' "$1"
}

# First `backticked` span across a (possibly multi-line) string, unquoted.
first_backtick() {
  printf '%s\n' "$1" | awk '
    { if (match($0, /`[^`]+`/)) { print substr($0, RSTART + 1, RLENGTH - 2); exit } }
  '
}

# The plan's own slug — its basename with the .md extension and a trailing
# -YYYY-MM-DD date stripped. The one piece cmd_start (handoff path + agent
# name) and fleet's in-flight check (handoff path only) both derive from
# the same plan file — kept in one place so the two can never disagree.
plan_slug_of() { # $1 = plan (absolute)
  local slug
  slug="$(basename "$1" .md)"
  printf '%s' "$slug" | sed -E 's/-[0-9]{4}-[0-9]{2}-[0-9]{2}$//'
}

# One fleet / start per plan at a time. Two overlapping fleet runs both
# snapshot the worktree list before either creates one, so both emitted —
# and would launch — every ready task (34/40 overlapping runs, 2026-09-23).
# mkdir is the atomic test-and-set; the lock sits in the git common dir
# (never staged, shared by every worktree). fleet takes it for the whole run;
# its own `start` calls run in a subshell that sees TICKET_LOCK already set.
TICKET_LOCK=""
take_plan_lock() { # $1 = subcommand, $2 = plan (absolute), $3 = repo root
  [ -z "$TICKET_LOCK" ] || return 0
  local common lock pid
  # cd into it rather than --path-format=absolute (git 2.31+ only): the
  # common dir may come back relative to $3.
  common="$(cd "$3" && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd)"
  [ -n "$common" ] || { echo "ticket: $1: cannot resolve the git dir of $3" >&2; exit 2; }
  lock="$common/rolepod-ticket-$(plan_slug_of "$2").lock"
  if ! mkdir "$lock" 2>/dev/null; then
    if [ ! -d "$lock" ]; then
      echo "ticket: $1: cannot create the plan lock $lock" >&2
      exit 1
    fi
    pid="$(cat "$lock/pid" 2>/dev/null)"
    # A holder that is gone left a stale lock: take it over. No pid yet
    # means a holder that has not written it — treat as live.
    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null && rm -rf "$lock" && mkdir "$lock" 2>/dev/null; then
      :
    else
      echo "ticket: $1: another fleet / start is running for this plan (pid ${pid:-unknown}) — re-run when it ends; no such process → rm -rf $lock" >&2
      exit 1
    fi
  fi
  echo "$$" > "$lock/pid"
  TICKET_LOCK="$lock"
  trap 'rm -rf "$TICKET_LOCK"' EXIT
}

# The backticked `git worktree add -b <branch> <path> [<base>]` command
# line from a handoff file's own "## Worktree" section — the one thing
# both cmd_start (branch + path) and fleet's in-flight check (path only)
# parse out of it, kept in one place so a plan-lint template change only
# needs fixing here.
handoff_worktree_cmd() { # $1 = handoff file
  local wtline
  wtline="$(section_body "$1" '## Worktree' | grep -m1 'git worktree add')"
  first_backtick "$wtline"
}

# I3: the brief FILE is the only thing read here — never plan-lint's
# internals — so this script stays correct whether or not the "## Proof"
# section exists yet.
extract_proof_command() { # $1 = brief file — line 2's backticked span, optional
  local body line2
  body="$(section_body "$1" '## Proof')"
  [ -n "$body" ] || return 0
  line2="$(printf '%s\n' "$body" | sed -n '2p')"
  [ -n "$line2" ] || return 0
  first_backtick "$line2"
}

# Task N and its plan's absolute path, off a brief's own first two lines
# ("# Task N: ..." / "Plan: <path> · Spec: ...", both stamped by plan-lint.sh
# --brief) — read back so integrate's ship-chain tail names the same `log`
# call `start` already printed, with no new CLI argument. Empty on a brief
# that predates this header shape (an ad hoc test fixture, say).
brief_task_n() { # $1 = brief file
  sed -n '1s/^# Task \([0-9][0-9]*\):.*/\1/p' "$1"
}

brief_plan_path() { # $1 = brief file
  sed -n '2s/^Plan: \(.*\) · Spec:.*/\1/p' "$1"
}

# The commit -> finish -> log tail of the ONE ship chain (spec lean-loop-
# 2026-09-23 Task 2), shared verbatim by `start`'s "ship:" line and
# `integrate`'s own success output. <subject>/<note> stay literal
# placeholders for the Lead to fill; "$(git -C <base> rev-parse --short
# HEAD)" is printed literal too — it runs only when the Lead pastes and
# runs the chain, and reads the base checkout, since `finish` (the step
# before it in the chain) merges the commit there and removes the worktree
# — the caller's own cwd may be neither.
ship_chain_tail() { # $1 = worktree (absolute), $2 = plan (absolute), $3 = task N, $4 = base checkout (absolute)
  printf 'git -C '\''%s'\'' commit -m '\''<subject>'\'' && rolepod-ticket finish '\''%s'\'' && rolepod-ticket log '\''%s'\'' %s --sha "$(git -C '\''%s'\'' rev-parse --short HEAD)" --note '\''<note>'\''' \
    "$1" "$1" "$2" "$3" "$4"
}

# scripts/plan-lint.sh --brief does not auto-resolve the contract path (only
# its non---brief path does, and that file is out of scope for this task) —
# this is the same 5-line lookup duplicated on purpose: a plan's own
# "## Parallel layout" backticked *.md path, resolved against the plan's
# dir, then the repo root.
resolve_contract() { # $1 = plan (absolute), $2 = repo root
  local layout rel plan_dir cand
  layout="$(awk '/^## Parallel layout/{f=1;next} /^## /{f=0} f' "$1")"
  rel="$(printf '%s\n' "$layout" | grep -oE '`[^`]+\.md`' | head -1 | tr -d '`')"
  [ -n "$rel" ] || return 0
  plan_dir="$(dirname "$1")"
  for cand in "$plan_dir/$rel" "$2/$rel" "$rel"; do
    if [ -f "$cand" ]; then printf '%s' "$cand"; return 0; fi
  done
  return 0
}

# A value flag given last has no value: `shift 2` then fails WITHOUT
# shifting and the parse loop never ends — refuse it as a usage error.
need_val() { # $1 = subcommand, $2 = flag, $3 = args left ($#)
  [ "$3" -ge 2 ] && return 0
  echo "ticket: $1: $2 needs a value" >&2
  exit 2
}

# Runs "$2" (a shell command line, or empty/"(not in plan)"/"none" to skip)
# in dir "$3", printing "$1: ok" or "$1: FAIL" + a <=15-line tail. Returns
# the command's own exit status (0 on skip).
run_step() {
  local label="$1" cmdstr="$2" cwd="$3" out rc
  if [ -z "$cmdstr" ] || [ "$cmdstr" = "(not in plan)" ] || [ "$cmdstr" = "none" ]; then
    return 0
  fi
  out="$(cd "$cwd" && bash -c "$cmdstr" 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "$label: ok"
    return 0
  fi
  echo "$label: FAIL"
  printf '%s\n' "$out" | tail -n 15
  echo "Fix: send this tail to the task owner in a NEW dispatch (it fixes, integrate again); the Lead never repairs it."
  return "$rc"
}

# The owner agent name, when the brief that names this worktree recorded one
# (an "Agent: <name>" line — optional; most briefs will have none). Matched
# by the EXACT basename of the brief's own "## Worktree" path, never a
# substring scan of the file — "-t1" is a literal substring of "-t11", so a
# text-contains check would resolve Task 1's worktree to Task 11's brief
# (or vice versa) whenever both exist side by side.
find_owner_agent() { # $1 = main root, $2 = worktree (absolute)
  local dir base f agent wtcmd path pbase
  dir="$1/docs/rolepod/handoffs"
  [ -d "$dir" ] || return 0
  base="$(basename "$2")"
  for f in "$dir"/*.md; do
    [ -f "$f" ] || continue
    wtcmd="$(handoff_worktree_cmd "$f")"
    [ -n "$wtcmd" ] || continue
    path="$(printf '%s\n' "$wtcmd" | awk '{print $6}')"
    [ -n "$path" ] || continue
    pbase="$(basename "$path")"
    if [ "$pbase" = "$base" ]; then
      agent="$(awk '/^Agent:/{sub(/^Agent:[[:space:]]*/,""); print; exit}' "$f")"
      if [ -n "$agent" ]; then printf '%s' "$agent"; return 0; fi
    fi
  done
  return 0
}

# One row per task: "<id>\t<owner>\t<blocked-ids-csv>\t<done 0|1>" — done
# means no remaining `- [ ]` inside the task's own block (`ticket log` flips
# every one to `- [x]`). A `(...)` aside on a Blocked-by reference (real
# plans annotate each blocker, e.g. "Task 1 (`start` exists), Task 3 (...)")
# is stripped per-reference, not from the first "(" to end of line — that
# would drop every reference after the first blocker's own aside. A trailing
# em/en-dash aside with no parens is stripped too, the same as parenthesised
# ones. plan-lint.sh's own (advisory-only) Blocked-by graph check now uses
# the identical two-step strip (T2 follow-up) — the two parsers agree on
# every ref shape either one is asked to read.
plan_task_rows() { # $1 = plan (absolute)
  awk -v fs="$ROW_FS" '
    function trim(x) { sub(/^[[:space:]]+/, "", x); sub(/[[:space:]]+$/, "", x); return x }
    function flush() {
      if (id == "") return
      bv = B
      gsub(/\([^)]*\)/, "", bv)
      # then a trailing em/en-dash aside (no parens) — "Task 3 — landed in
      # v2.90.0" must resolve to {3}, not pick up 2/90/0 out of the prose —
      # mirrors the two-step strip plan-lint.sh now uses (T2 follow-up).
      sub(/[[:space:]]+(—|–)[[:space:]]+.*$/, "", bv)
      blist = ""
      low = tolower(trim(bv))
      if (low != "" && low !~ /^(none|—|-|–)/) {
        rem = bv
        while (match(rem, /[0-9]+/)) {
          r = substr(rem, RSTART, RLENGTH); rem = substr(rem, RSTART + RLENGTH)
          blist = (blist == "" ? r : blist "," r)
        }
      }
      # A task with NO checkbox at all (every field a bare "- **Label:**"
      # bullet, a shape the Command check above also accepts) is not
      # vacuously "done": total_boxes guards against reading it as an
      # immediately-satisfied blocker for everything that names it.
      done = (total_boxes > 0 && open_boxes == 0) ? 1 : 0
      printf "%s%s%s%s%s%s%d\n", id, fs, trim(Ow), fs, blist, fs, done
    }
    $0 ~ /^### (Task ?|T)[0-9]+/ {
      flush()
      id = $0; sub(/^### (Task ?|T)/, "", id); sub(/[^0-9].*$/, "", id)
      B = ""; Ow = ""; open_boxes = 0; total_boxes = 0; field = ""
      next
    }
    /^## / { flush(); id = ""; next }
    id != "" {
      line = $0
      # A field is ONLY a line whose trimmed start is "- **<Field>:**" (a
      # checkbox may sit between the dash and the bold label) — any other
      # mention (a Test / evidence sentence quoting the same words) is prose
      # and must never be read as the field itself.
      tl = trim(line)
      if (tl ~ /^-([[:space:]]*\[[ xX]\])?[[:space:]]*\*\*Blocked by:\*\*/) {
        v = line; sub(/.*\*\*Blocked by:\*\*[[:space:]]*/, "", v)
        B = trim(v); field = "B"; next
      }
      if (tl ~ /^-([[:space:]]*\[[ xX]\])?[[:space:]]*\*\*Owner:\*\*/) {
        v = line; sub(/.*\*\*Owner:\*\*[[:space:]]*/, "", v)
        Ow = trim(v); field = "O"; next
      }
      if (line ~ /^[[:space:]]*-[[:space:]]*\[[[:space:]]\]/) { open_boxes++; total_boxes++; field = ""; next }
      if (line ~ /^[[:space:]]*-[[:space:]]*\[[xX]\]/) { total_boxes++; field = ""; next }
      if (field != "" && trim(line) != "" && line !~ /^[-*][[:space:]]/) {
        if (field == "B") B = B " " trim(line)
        else if (field == "O") Ow = Ow " " trim(line)
        next
      }
      next
    }
    END { flush() }
  ' "$1"
}

# Space-padded set " <id> <id> ... " of every task marked done in rows
# "$1" (a plan_task_rows table) — the one done-id lookup ready_role_tasks
# and log's ready-now line both build from, so a done check can never
# disagree between the two callers.
done_ids_of() { # $1 = plan_task_rows output
  local id owner blocked done out=" "
  while IFS="$ROW_FS" read -r id owner blocked done; do
    [ -n "$id" ] || continue
    [ "$done" = "1" ] && out="$out$id "
  done <<EOF
$1
EOF
  printf '%s' "$out"
}

# True (rc 0) when Owner field "$1" is the Lead, not a role — the one Lead
# test ready_role_tasks and log's ready-now line both apply, so a
# role-owned check can never disagree between the two callers.
is_lead_owner() { # $1 = owner field
  local owner="$1" lead_rx='^Lead([[:space:](]|$)'
  [[ "$owner" =~ $lead_rx ]] || [[ "$owner" == *"(Lead self-do)"* ]]
}

# True (rc 0) when every comma-separated blocker id in "$1" is present in
# done-id set "$2" (from done_ids_of) — an empty "$1" (no Blocked-by) is
# vacuously done. The one "are its blockers all done" test ready_role_tasks
# and ready_now_after both apply, so they can never disagree.
all_blockers_done() { # $1 = blocked (comma list, may be empty), $2 = done_ids set
  local blocked="$1" done_ids="$2" bid oldifs ok=1
  if [ -n "$blocked" ]; then
    oldifs="$IFS"; IFS=','
    for bid in $blocked; do
      case "$done_ids" in *" $bid "*) : ;; *) ok=0 ;; esac
    done
    IFS="$oldifs"
  fi
  [ "$ok" -eq 1 ]
}

# Role-owned (non-Lead) task ids whose every Blocked-by task is done — the
# one definition of "ready" shared by start's fleet hint below and by
# `fleet` itself, so the two can never disagree on which tasks qualify.
ready_role_tasks() { # $1 = plan (absolute)
  local plan="$1" rows id owner blocked done done_ids
  rows="$(plan_task_rows "$plan")"
  done_ids="$(done_ids_of "$rows")"
  while IFS="$ROW_FS" read -r id owner blocked done; do
    [ -n "$id" ] || continue
    # already done (every box in ITS OWN block checked) — nothing left to
    # build; the Blocked-by graph only cares about a done BLOCKER, not this.
    [ "$done" = "1" ] && continue
    is_lead_owner "$owner" && continue
    all_blockers_done "$blocked" "$done_ids" && printf '%s\n' "$id"
  done <<EOF
$rows
EOF
}

# Not-done tasks whose Blocked-by list names task "$2" and whose every
# blocker is now done — the set `log` reports as "just became ready" after
# flipping Task "$2"'s own checkboxes. Any owner, Lead included; the caller
# decides the fleet-hint line separately (`is_lead_owner` per row). One row
# per line: "<id><ROW_FS><owner>".
ready_now_after() { # $1 = plan, $2 = task id just logged
  local plan="$1" want="$2" rows id owner blocked done done_ids
  rows="$(plan_task_rows "$plan")"
  done_ids="$(done_ids_of "$rows")"
  while IFS="$ROW_FS" read -r id owner blocked done; do
    [ -n "$id" ] || continue
    [ "$done" = "1" ] && continue
    # only a task whose Blocked-by list names $want at all — a task that
    # was already ready for other reasons is not "just became ready" here.
    case ",$blocked," in *",$want,"*) : ;; *) continue ;; esac
    all_blockers_done "$blocked" "$done_ids" && printf '%s%s%s\n' "$id" "$ROW_FS" "$owner"
  done <<EOF
$rows
EOF
}

json_escape() { # $1 = string -> backslash/quote escaped for a JSON string body
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

# The brief's "## Reviewers" first line, as backticked role tokens — the
# pool-command alternative (`rolepod-cross-family --kind review ...`) always
# carries a space and "none" (R1) is dropped, so only real role names survive.
brief_reviewers() { # $1 = brief file
  local line1
  line1="$(section_body "$1" '## Reviewers' | sed -n '1p')"
  printf '%s\n' "$line1" | grep -oE '`[^`]+`' | tr -d '`' | grep -vx 'none' | grep -v ' ' || true
}

# Reviewer tokens on stdin (one per line, from brief_reviewers) -> a compact
# JSON array literal, e.g. ["universal-reviewer","qa-tester"].
reviewers_json_array() {
  local rev out="" first=1
  while IFS= read -r rev; do
    [ -n "$rev" ] || continue
    if [ "$first" -eq 1 ]; then out="\"$(json_escape "$rev")\""; first=0
    else out="${out},\"$(json_escape "$rev")\""; fi
  done
  printf '[%s]' "$out"
}

# ── start ────────────────────────────────────────────────────────────────

cmd_start() {
  local plan="${1:-}"; shift || true
  local n="${1:-}"; shift || true
  local base=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --base) need_val start --base $#; base="$2"; shift 2 ;;
      *) echo "ticket: start: unknown arg: $1" >&2; exit 2 ;;
    esac
  done
  if [ -z "$plan" ] || [ ! -f "$plan" ] || [ -z "$n" ]; then
    usage >&2; exit 2
  fi
  [ -f "$LINT" ] || { echo "ticket: start: plan-lint.sh not found beside $0 or in ~/.rolepod/bin" >&2; exit 2; }

  local plan_dir plan_abs repo_root
  plan_dir="$(cd "$(dirname "$plan")" && pwd)"
  plan_abs="$plan_dir/$(basename "$plan")"
  repo_root="$(git -C "$plan_dir" rev-parse --show-toplevel 2>/dev/null)"
  [ -n "$repo_root" ] || { echo "ticket: start: not inside a git repo: $plan_abs" >&2; exit 2; }
  take_plan_lock start "$plan_abs" "$repo_root"

  [ -n "$base" ] || base="$(git -C "$repo_root" rev-parse --abbrev-ref HEAD)"

  local lint_out
  if ! lint_out="$(bash "$LINT" "$plan_abs" 2>&1)"; then
    printf '%s\n' "$lint_out" >&2
    echo "ticket: start: plan-lint FAIL — fix the plan before a task starts from it" >&2
    exit 1
  fi

  local contract
  contract="$(resolve_contract "$plan_abs" "$repo_root")"

  local brief_out brief_rc
  if [ -n "$contract" ]; then
    brief_out="$(bash "$LINT" --brief "$n" "$plan_abs" "$contract" 2>&1)"
  else
    brief_out="$(bash "$LINT" --brief "$n" "$plan_abs" 2>&1)"
  fi
  brief_rc=$?
  if [ "$brief_rc" -ne 0 ]; then
    printf '%s\n' "$brief_out" >&2
    exit 1
  fi

  local plan_slug handoff_dir handoff
  plan_slug="$(plan_slug_of "$plan_abs")"
  handoff_dir="$repo_root/docs/rolepod/handoffs"
  mkdir -p "$handoff_dir"
  handoff="$handoff_dir/${plan_slug}-t${n}-owner.md"
  local agent_name agent_line
  agent_name="owner-${plan_slug}-t${n}"
  agent_line="Agent: $agent_name"
  if [ ! -f "$handoff" ] || [ "$(cat "$handoff" 2>/dev/null)" != "$brief_out"$'\n'"$agent_line" ]; then
    printf '%s\n%s\n' "$brief_out" "$agent_line" > "$handoff"
  fi

  local wtcmd branch wtpath wtparent wt_abs
  wtcmd="$(handoff_worktree_cmd "$handoff")"
  [ -n "$wtcmd" ] || { echo "ticket: start: no worktree command found in $handoff" >&2; exit 2; }
  branch="$(printf '%s\n' "$wtcmd" | awk '{print $5}')"
  wtpath="$(printf '%s\n' "$wtcmd" | awk '{print $6}')"
  [ -n "$branch" ] && [ -n "$wtpath" ] || { echo "ticket: start: could not parse worktree command: $wtcmd" >&2; exit 2; }

  wtparent="$(cd "$repo_root/$(dirname "$wtpath")" 2>/dev/null && pwd)"
  [ -n "$wtparent" ] || { echo "ticket: start: could not resolve the worktree path from $wtpath" >&2; exit 2; }
  wt_abs="$wtparent/$(basename "$wtpath")"

  # -x: an exact whole-line match — "worktree $wt_abs" as a plain substring
  # would also match a sibling worktree whose path this one merely prefixes
  # (e.g. .../t1 inside .../t11), the same rule find_owner_agent already
  # applies to a brief's basename above.
  if git -C "$repo_root" worktree list --porcelain 2>/dev/null | grep -qxF "worktree $wt_abs"; then
    : # existing worktree — idempotent, nothing to create
  else
    local add_out
    # A branch left behind by a manual `worktree remove` (the branch itself
    # was never deleted) needs a plain add, not -b — otherwise git's own
    # multi-line "branch already exists" error breaks the one-line-message rule.
    local add_rc
    if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch"; then
      add_out="$(git -C "$repo_root" worktree add "$wt_abs" "$branch" 2>&1)"; add_rc=$?
    else
      add_out="$(git -C "$repo_root" worktree add -b "$branch" "$wt_abs" "$base" 2>&1)"; add_rc=$?
      # `worktree add -b` creates the branch before it checks the path, so a
      # failure leaves a new empty branch behind — this call made it, drop it.
      [ "$add_rc" -eq 0 ] || git -C "$repo_root" branch -D "$branch" >/dev/null 2>&1
    fi
    if [ "$add_rc" -ne 0 ]; then
      printf '%s\n' "$add_out" >&2
      exit 1
    fi
  fi

  printf '%s %s\n' "$handoff" "$wt_abs"
  printf 'agent: %s\n' "$agent_name"
  printf 'ship: rolepod-ticket integrate '\''%s'\'' --brief '\''%s'\'' --gate '\''<commit gate>'\'' && %s\n' \
    "$wt_abs" "$handoff" "$(ship_chain_tail "$wt_abs" "$plan_abs" "$n" "$repo_root")"

  local ready_count
  ready_count="$(ready_role_tasks "$plan_abs" | grep -c '.')"
  if [ "$ready_count" -ge 2 ]; then
    printf 'fleet: rolepod-ticket fleet %s\n' "$plan_abs"
  fi
}

# ── integrate ────────────────────────────────────────────────────────────

cmd_integrate() {
  local wt="${1:-}"; shift || true
  local brief="" pre="" gate=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --brief) need_val integrate --brief $#; brief="$2"; shift 2 ;;
      --pre) need_val integrate --pre $#; pre="$2"; shift 2 ;;
      --gate) need_val integrate --gate $#; gate="$2"; shift 2 ;;
      *) echo "ticket: integrate: unknown arg: $1" >&2; exit 2 ;;
    esac
  done
  if [ -z "$wt" ] || [ ! -d "$wt" ] || [ -z "$brief" ] || [ ! -f "$brief" ]; then
    usage >&2; exit 2
  fi

  local wt_root main_root base_branch dirty ahead ahead_rc
  wt_root="$(cd "$wt" && pwd)"
  main_root="$(main_root_of "$wt_root")"
  [ -n "$main_root" ] || { echo "ticket: integrate: cannot resolve the main checkout for $wt_root" >&2; exit 2; }
  if [ "$main_root" = "$wt_root" ]; then
    echo "ticket: integrate: $wt_root is the main checkout, not a linked worktree — refusing" >&2
    exit 2
  fi
  base_branch="$(git -C "$main_root" rev-parse --abbrev-ref HEAD)"
  if [ "$base_branch" = "HEAD" ]; then
    echo "ticket: integrate: the main checkout at $main_root is in a detached HEAD state — refusing (no named base branch)" >&2
    exit 1
  fi

  dirty=""
  [ -n "$(git -C "$wt_root" status --porcelain)" ] && dirty=1
  ahead="$(git -C "$wt_root" rev-list --count "$base_branch..HEAD" 2>/dev/null)"
  ahead_rc=$?
  if [ "$ahead_rc" -ne 0 ]; then
    echo "ticket: integrate: cannot resolve $base_branch..HEAD in $wt_root — refusing (fail-closed)" >&2
    exit 1
  fi
  ahead="${ahead:-0}"
  if [ "$ahead" -gt 0 ] && [ -n "$dirty" ]; then
    echo "ticket: integrate: ambiguous — $ahead commit(s) ahead of $base_branch AND a dirty tree; resolve by hand first" >&2
    exit 1
  fi

  run_step "pre" "$pre" "$wt_root" || exit $?

  local merge_out merge_rc
  merge_out="$(git -C "$wt_root" merge --ff-only "$base_branch" 2>&1)"
  merge_rc=$?
  if [ "$merge_rc" -eq 0 ]; then
    echo "merge: ok"
  else
    echo "merge: FAIL"
    printf '%s\n' "$merge_out" | tail -n 15
    exit "$merge_rc"
  fi

  local stage_out stage_rc
  stage_out="$(git -C "$wt_root" add -A -- . ':(exclude)docs/rolepod' 2>&1)"
  stage_rc=$?
  if [ "$stage_rc" -eq 0 ]; then
    echo "stage: ok"
  else
    echo "stage: FAIL"
    printf '%s\n' "$stage_out" | tail -n 15
    exit "$stage_rc"
  fi

  local proof_str
  proof_str="$(extract_proof_command "$brief")"

  run_step "proof" "$proof_str" "$wt_root" || exit $?
  run_step "gate" "$gate" "$wt_root" || exit $?

  git -C "$wt_root" diff --cached --stat | tail -n 3

  # A reviewer report can land under the main checkout's evidence root (the
  # Lead's own convention) or the worktree's own (an owner working inside it
  # per its Bounds) — both are scanned, deduped by basename, newest first,
  # capped so this block alone cannot blow the <=40-line budget.
  local marker review_list f b v seen
  marker="$wt_root/.git"
  review_list="$(mktemp "${TMPDIR:-/tmp}/rolepod-ticket-review.XXXXXX")"
  {
    [ -d "$main_root/.rolepod/evidence/review" ] && find "$main_root/.rolepod/evidence/review" -type f -newer "$marker" 2>/dev/null
    if [ "$wt_root/.rolepod/evidence/review" != "$main_root/.rolepod/evidence/review" ] \
      && [ -d "$wt_root/.rolepod/evidence/review" ]; then
      find "$wt_root/.rolepod/evidence/review" -type f -newer "$marker" 2>/dev/null
    fi
  } | sort > "$review_list"
  seen=""
  while IFS= read -r f; do
    b="$(basename "$f")"
    case " $seen " in *" $b "*) continue ;; esac
    seen="$seen $b"
    v="$(grep -m1 '^VERDICT:' "$f" 2>/dev/null)"
    [ -n "$v" ] && printf '%s: %s\n' "$b" "$v"
  done < "$review_list" | head -n 10
  rm -f "$review_list"

  local plan_abs task_n
  plan_abs="$(brief_plan_path "$brief")"
  task_n="$(brief_task_n "$brief")"
  if [ -n "$plan_abs" ] && [ -n "$task_n" ]; then
    printf '%s\n' "$(ship_chain_tail "$wt_root" "$plan_abs" "$task_n" "$main_root")"
  else
    printf 'git -C "%s" commit -m "<subject>"\n' "$wt_root"
  fi
}

# ── finish ───────────────────────────────────────────────────────────────

cmd_finish() {
  local wt="${1:-}"
  if [ -z "$wt" ] || [ ! -d "$wt" ]; then usage >&2; exit 2; fi

  local wt_root main_root branch base_branch
  wt_root="$(cd "$wt" && pwd)"
  main_root="$(main_root_of "$wt_root")"
  [ -n "$main_root" ] || { echo "ticket: finish: cannot resolve the main checkout for $wt_root" >&2; exit 2; }
  if [ "$main_root" = "$wt_root" ]; then
    echo "ticket: finish: $wt_root is the main checkout, not a linked worktree" >&2
    exit 2
  fi

  if [ -n "$(git -C "$wt_root" status --porcelain)" ]; then
    echo "ticket: finish: worktree is dirty — commit or discard first: $wt_root" >&2
    exit 1
  fi

  branch="$(git -C "$wt_root" rev-parse --abbrev-ref HEAD)"
  base_branch="$(git -C "$main_root" rev-parse --abbrev-ref HEAD)"
  if [ "$base_branch" = "HEAD" ]; then
    echo "ticket: finish: the main checkout at $main_root is in a detached HEAD state — refusing (no named base branch)" >&2
    exit 1
  fi

  if ! git -C "$wt_root" merge-base --is-ancestor "$base_branch" HEAD 2>/dev/null; then
    echo "ticket: finish: $branch is not an ancestor-or-equal of $base_branch's committed state — nothing to merge (integrate + commit first)" >&2
    exit 1
  fi

  local merge_out merge_rc
  merge_out="$(git -C "$main_root" merge --ff-only "$branch" 2>&1)"
  merge_rc=$?
  if [ "$merge_rc" -ne 0 ]; then
    echo "ticket: finish: fast-forward merge failed:" >&2
    printf '%s\n' "$merge_out" | tail -n 15 >&2
    exit "$merge_rc"
  fi

  if ! git -C "$main_root" worktree remove "$wt_root" >/dev/null 2>&1; then
    echo "ticket: finish: worktree remove failed for $wt_root" >&2
    exit 1
  fi
  git -C "$main_root" worktree prune >/dev/null 2>&1 || true
  git -C "$main_root" branch -d "$branch" >/dev/null 2>&1 \
    || echo "ticket: finish: branch $branch left in place (delete by hand)" >&2

  local agent
  agent="$(find_owner_agent "$main_root" "$wt_root")"
  echo "close: ${agent:-(unrecorded)}"
}

# ── log ──────────────────────────────────────────────────────────────────

cmd_log() {
  local plan="${1:-}"; shift || true
  local n="${1:-}"; shift || true
  local sha="" note=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --sha) need_val log --sha $#; sha="$2"; shift 2 ;;
      --note) need_val log --note $#; note="$2"; shift 2 ;;
      *) echo "ticket: log: unknown arg: $1" >&2; exit 2 ;;
    esac
  done
  if [ -z "$plan" ] || [ ! -f "$plan" ] || [ -z "$n" ] || [ -z "$sha" ] || [ -z "$note" ]; then
    usage >&2; exit 2
  fi

  if ! grep -q '^## Changes during build' "$plan"; then
    echo "ticket: log: no '## Changes during build' heading in $plan — refusing (fail-closed)" >&2
    exit 1
  fi

  local tmp rc bullet
  tmp="$(mktemp "${TMPDIR:-/tmp}/rolepod-ticket-log.XXXXXX")"
  [ -n "$tmp" ] || { echo "ticket: log: mktemp failed" >&2; exit 1; }

  awk -v want="$n" '
    /^### / {
      if ($0 ~ /^### (Task ?|T)[0-9]+/) {
        id = $0; sub(/^### (Task ?|T)/, "", id); sub(/[^0-9].*$/, "", id)
        intask = (id == want) ? 1 : 0
      } else intask = 0
      print; next
    }
    /^## / { intask = 0; print; next }
    intask && /^- \[ \]/ { sub(/\[ \]/, "[x]"); print; next }
    { print }
  ' "$plan" > "$tmp"
  rc=$?
  if [ "$rc" -ne 0 ] || [ ! -s "$tmp" ]; then
    echo "ticket: log: checkbox pass failed — refusing to write $plan" >&2
    rm -f "$tmp"; exit 1
  fi

  # The gate writes to the plan, never reads from it (spec Desired 10): the
  # newest phase-log "gate" row whose head is this commit's PARENT ("$sha^")
  # carries what the gate counted for it. No repo, no phase-log, or no
  # matching row → "gate: no record" (fail-open, still appended).
  local gate_repo_root gate_phase_log gate_parent_sha gate_str
  gate_str="gate: no record"
  gate_repo_root="$(git -C "$(dirname "$plan")" rev-parse --show-toplevel 2>/dev/null)"
  if [ -n "$gate_repo_root" ]; then
    gate_phase_log="$gate_repo_root/.rolepod/evidence/phase-log.jsonl"
    if [ -f "$gate_phase_log" ]; then
      gate_parent_sha="$(git -C "$gate_repo_root" rev-parse "${sha}^" 2>/dev/null)"
      if [ -n "$gate_parent_sha" ]; then
        local found
        found="$(TICKET_GATE_PARENT="$gate_parent_sha" python3 -I -c '
import json, os, sys
parent = os.environ.get("TICKET_GATE_PARENT") or ""
best = None
try:
    with open(sys.argv[1], encoding="utf-8", errors="replace") as f:
        for line in f:
            try:
                d = json.loads(line)
            except Exception:
                continue
            if not isinstance(d, dict):
                continue
            if d.get("phase") != "gate" or d.get("head") != parent:
                continue
            best = d  # last match in an append-only file = newest
except Exception:
    best = None
if best is not None:
    def _int(k):
        try:
            return int(best.get(k) or 0)
        except Exception:
            return 0
    # security-engineer review (2026-09-24, gate-evidence-paths T9): the
    # decision field is untrusted (a stale/forged phase-log row) — this
    # line is a convenience note, not tamper-proof audit evidence, so it
    # is constrained to the three real decisions rather than echoed raw.
    _decision = best.get("decision")
    if _decision not in ("pass", "deny", "soft"):
        _decision = "?"
    print("gate: %s · tests %d · risk %d · reviewers %d (strong %d, external %d)" % (
        _decision, _int("tests"), _int("risk"),
        _int("reviewers"), _int("strong"), _int("external")))
' "$gate_phase_log" 2>/dev/null)"
        [ -n "$found" ] && gate_str="$found"
      fi
    fi
  fi
  note="$note $gate_str"

  # Idempotent: the exact same bullet is never appended twice — but only a
  # look-alike line INSIDE "## Changes during build" counts; a Test /
  # evidence sentence elsewhere in the plan quoting the same words is prose,
  # not a prior log entry.
  bullet="- Task $n (\`$sha\`): $note"
  local existing_section
  existing_section="$(awk '
    /^## Changes during build/ { insec = 1; next }
    insec && /^## / { exit }
    insec { print }
  ' "$tmp")"
  if printf '%s\n' "$existing_section" | grep -qF -- "$bullet"; then
    cp "$tmp" "$tmp.2"
    rc=$?
  else
    # The note is free text (may hold a backslash) — pass it through the
    # environment, never `awk -v`, which interprets backslash escapes and
    # would mangle it.
    TICKET_LOG_NOTE="$note" awk -v n="$n" -v sha="$sha" '
      /^## Changes during build/ { print; insec = 1; next }
      insec && /^## / {
        printf "- Task %s (`%s`): %s\n\n", n, sha, ENVIRON["TICKET_LOG_NOTE"]
        added = 1; insec = 0
        print; next
      }
      { print }
      END { if (insec && !added) printf "- Task %s (`%s`): %s\n\n", n, sha, ENVIRON["TICKET_LOG_NOTE"] }
    ' "$tmp" > "$tmp.2"
    rc=$?
  fi
  if [ "$rc" -ne 0 ] || [ ! -s "$tmp.2" ]; then
    echo "ticket: log: bullet pass failed — refusing to write $plan" >&2
    rm -f "$tmp" "$tmp.2"; exit 1
  fi

  mv "$tmp.2" "$plan"
  rm -f "$tmp"
  echo "ticket: log: Task $n updated in $plan"

  local ready_rows id2 owner2 list="" has_role=0
  ready_rows="$(ready_now_after "$plan" "$n")"
  if [ -n "$ready_rows" ]; then
    while IFS="$ROW_FS" read -r id2 owner2; do
      [ -n "$id2" ] || continue
      if [ -n "$list" ]; then list="$list, Task $id2 ($owner2)"; else list="Task $id2 ($owner2)"; fi
      is_lead_owner "$owner2" || has_role=1
    done <<EOF
$ready_rows
EOF
    echo "ready now: $list"
    # `if`, not `&&`: cmd_log's exit status is its last command's — a bare
    # `[ ... ] && printf ...` would make log exit 1 (a false "failure")
    # whenever every newly-ready task is Lead-owned, on an otherwise
    # successful write.
    if [ "$has_role" -eq 1 ]; then
      printf 'fleet: rolepod-ticket fleet %s\n' "$plan"
    fi
  fi

  # ONE combined review before release (spec lean-loop-2026-09-23 Task 2,
  # implement-plan Review): once every role-owned task's own block is fully
  # checked, name the range from the FIRST task this plan ever logged (its
  # parent commit) through HEAD — never before every role task is done, and
  # a re-run after that point reprints the same line (idempotent, like
  # "ready now:" above). A Lead-only plan (no role-owned task at all) never
  # prints it — there is nothing for the Lead to review that it did not
  # already build.
  local rrows rid rowner rblocked rdone role_total=0 role_done=0
  rrows="$(plan_task_rows "$plan")"
  while IFS="$ROW_FS" read -r rid rowner rblocked rdone; do
    [ -n "$rid" ] || continue
    is_lead_owner "$rowner" && continue
    role_total=$((role_total + 1))
    [ "$rdone" = "1" ] && role_done=$((role_done + 1))
  done <<EOF
$rrows
EOF
  if [ "$role_total" -gt 0 ] && [ "$role_total" -eq "$role_done" ]; then
    local first_sha
    # Anchored to the exact bullet shape this function writes above
    # ("- Task N (`<sha>`): <note>") — never the first backticked span in
    # the section, which a Lead deviation line ("Task N — what changed,
    # why") can also hold, ahead of the first real log bullet.
    first_sha="$(awk '
      /^## Changes during build/ { insec = 1; next }
      insec && /^## / { exit }
      insec && /^- Task [0-9]+ \(`/ && match($0, /`[^`]+`/) { print substr($0, RSTART + 1, RLENGTH - 2); exit }
    ' "$plan")"
    if [ -n "$first_sha" ]; then
      # The lenses get the diff as a file (owner-approved 2026-09-24: a
      # reviewer has no shell). Written under the base checkout (the repo
      # holding the plan, not a task worktree) so every task's diff lands
      # in one place. A write failure (no repo, bad sha, unwritable dir)
      # never fails log — the range still prints, just without the path.
      # The attr:linguist-generated exclude needs a git that supports attr
      # pathspec magic for diff; a git that rejects it falls back to a plain
      # diff over the same range so the lens file still gets written.
      local review_line repo_root diff_dir diff_path diff_content
      review_line="review: ${first_sha}^..HEAD — one combined review before release (implement-plan Review)"
      repo_root="$(git -C "$(dirname "$plan")" rev-parse --show-toplevel 2>/dev/null)"
      if [ -n "$repo_root" ]; then
        diff_dir="$repo_root/.rolepod/evidence/review"
        diff_path="$diff_dir/$(plan_slug_of "$plan").diff"
        if mkdir -p "$diff_dir" 2>/dev/null; then
          if diff_content="$(git -C "$repo_root" diff "${first_sha}^..HEAD" -- . ':(exclude,attr:linguist-generated)' 2>/dev/null)" \
            || diff_content="$(git -C "$repo_root" diff "${first_sha}^..HEAD" 2>/dev/null)"; then
            if printf '%s\n' "$diff_content" > "$diff_path" 2>/dev/null; then
              review_line="$review_line; lens diff: $diff_path"
            fi
          fi
        fi
      fi
      printf '%s\n' "$review_line"
    fi
  fi
}

# ── fleet ────────────────────────────────────────────────────────────────

# The absolute worktree path recorded in an EXISTING handoff's own
# "## Worktree" line, resolved the same way cmd_start resolves one (field 6
# of handoff_worktree_cmd's line) — but read-only: it never creates the
# handoff or the worktree, so it is safe to call on a task `fleet` has not
# decided to start yet. Empty when the handoff doesn't exist, or its
# Worktree line doesn't parse.
handoff_worktree_path() { # $1 = handoff file, $2 = repo root
  [ -f "$1" ] || return 0
  local wtcmd wtpath wtparent
  wtcmd="$(handoff_worktree_cmd "$1")"
  [ -n "$wtcmd" ] || return 0
  wtpath="$(printf '%s\n' "$wtcmd" | awk '{print $6}')"
  [ -n "$wtpath" ] || return 0
  wtparent="$(cd "$2/$(dirname "$wtpath")" 2>/dev/null && pwd)"
  [ -n "$wtparent" ] || return 0
  printf '%s/%s' "$wtparent" "$(basename "$wtpath")"
}

# Comma-joined "Task a, Task b" from a space-separated list of ids, in the
# order given — the one formatter for every task-list line fleet prints.
task_list() { # $1 = space-separated ids
  local id out=""
  for id in $1; do
    if [ -z "$out" ]; then out="Task $id"; else out="$out, Task $id"; fi
  done
  printf '%s' "$out"
}

# Undo the worktrees a fleet run created before a later `start` failed —
# left in place they read as "in flight" on the next run and are never
# built. A branch this run created goes too; one that existed before the
# run (start reuses a branch left by a manual `worktree remove`) is kept.
rollback_worktrees() { # $1 = repo root, $2 = pre-run branch names, $3 = "id<ROW_FS>worktree" lines
  local root="$1" pre_branches="$2" id wt br undone="" left=""
  while IFS="$ROW_FS" read -r id wt; do
    [ -n "$id" ] || continue
    # Full refnames on both sides: `--short` forms disagree (for-each-ref
    # shortens strictly to "heads/x" when a remote ref shares the name).
    br="$(git -C "$wt" symbolic-ref --quiet HEAD 2>/dev/null)"
    if ! git -C "$root" worktree remove "$wt" >/dev/null 2>&1; then
      left="$left $wt"; continue
    fi
    # -D, not -d: created seconds ago by this run and nothing ran in its
    # worktree, but -d refuses a branch cut from a --base other than HEAD.
    if [ -n "$br" ] && ! printf '%s\n' "$pre_branches" | grep -qxF "$br"; then
      git -C "$root" branch -D "${br#refs/heads/}" >/dev/null 2>&1 || left="$left branch:${br#refs/heads/}"
    fi
    undone="$undone$id "
  done <<EOF
$3
EOF
  if [ -n "$undone" ]; then
    echo "ticket: fleet: rolled back this run's worktree(s): $(task_list "$undone")" >&2
  fi
  if [ -n "$left" ]; then
    echo "ticket: fleet: could not roll back — remove by hand:$left" >&2
  fi
}

cmd_fleet() {
  local plan="${1:-}"; shift || true
  local base="" gate="" max=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --base) need_val fleet --base $#; base="$2"; shift 2 ;;
      --gate) need_val fleet --gate $#; gate="$2"; shift 2 ;;
      --max)
        max="${2:-}"
        if ! [[ "$max" =~ ^[1-9][0-9]*$ ]]; then
          echo "ticket: fleet: --max requires a positive integer, got: ${max:-(none)}" >&2
          usage >&2
          exit 2
        fi
        shift 2
        ;;
      *) echo "ticket: fleet: unknown arg: $1" >&2; exit 2 ;;
    esac
  done
  if [ -z "$plan" ] || [ ! -f "$plan" ]; then usage >&2; exit 2; fi

  local plan_dir plan_abs repo_root script_path
  plan_dir="$(cd "$(dirname "$plan")" && pwd)"
  plan_abs="$plan_dir/$(basename "$plan")"
  repo_root="$(git -C "$plan_dir" rev-parse --show-toplevel 2>/dev/null)"
  [ -n "$repo_root" ] || { echo "ticket: fleet: not inside a git repo: $plan_abs" >&2; exit 2; }
  take_plan_lock fleet "$plan_abs" "$repo_root"

  if [ -n "$gate" ]; then
    local gate_out gate_rc
    gate_out="$(cd "$repo_root" && bash -c "$gate" 2>&1)"
    gate_rc=$?
    if [ "$gate_rc" -ne 0 ]; then
      printf '%s\n' "$gate_out" | tail -n 15
      echo "ticket: fleet: base gate red — no worktree created"
      exit 1
    fi
  fi

  local ready
  ready="$(ready_role_tasks "$plan_abs")"
  if [ -z "$ready" ]; then
    echo "ticket: fleet: no ready role-owned task in $plan_abs"
    return 0
  fi

  # Fail closed, same convention as $LINT above — a silently-wrong
  # scriptPath in the JSON (the ~/.rolepod/bin fallback is the EXPECTED
  # path on a marketplace-only Claude install, which ships no scripts/
  # ticket-fleet.js today; see build/render.sh) would only surface when the
  # Lead tries to launch it, worktrees and all already created.
  script_path="$SELF_DIR/ticket-fleet.js"
  [ -f "$script_path" ] || script_path="$HOME/.rolepod/bin/ticket-fleet.js"
  [ -f "$script_path" ] || { echo "ticket: fleet: ticket-fleet.js not found beside $0 or in ~/.rolepod/bin" >&2; exit 2; }

  # Snapshot existing worktrees BEFORE any `start` call this run might make,
  # so "in flight" always means "already running before this invocation".
  local wt_snapshot
  wt_snapshot="$(git -C "$repo_root" worktree list --porcelain 2>/dev/null)"

  local plan_slug handoff_dir
  plan_slug="$(plan_slug_of "$plan_abs")"
  handoff_dir="$repo_root/docs/rolepod/handoffs"

  # Pass 1 — split ready tasks (plan order) into in-flight vs remaining,
  # read only from a handoff `start` already wrote in an earlier run; never
  # calls `start` here, since that would create a worktree for a task that
  # may end up held back below.
  local n existing_handoff wt_abs inflight_ids="" remaining_ids=""
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    existing_handoff="$handoff_dir/${plan_slug}-t${n}-owner.md"
    wt_abs="$(handoff_worktree_path "$existing_handoff" "$repo_root")"
    # -x: an exact whole-line match — a plain substring would also match a
    # sibling worktree this one's path merely prefixes (e.g. .../t1 inside
    # .../t11).
    if [ -n "$wt_abs" ] && printf '%s\n' "$wt_snapshot" | grep -qxF "worktree $wt_abs"; then
      inflight_ids="$inflight_ids$n "
    else
      remaining_ids="$remaining_ids$n "
    fi
  done <<EOF
$ready
EOF

  # Pass 2 — apply --max to the remaining (not-in-flight) tasks, plan order.
  local keep_ids="" held_ids="" count=0
  for n in $remaining_ids; do
    if [ -z "$max" ] || [ "$count" -lt "$max" ]; then
      keep_ids="$keep_ids$n "
      count=$((count + 1))
    else
      held_ids="$held_ids$n "
    fi
  done

  local rows role start_out start_rc handoff wt2 revlist entry tasks_json="" first=1
  local started_rows="" pre_branches
  rows="$(plan_task_rows "$plan_abs")"
  pre_branches="$(git -C "$repo_root" for-each-ref --format='%(refname)' refs/heads 2>/dev/null)"

  # Validate EVERY kept task's Owner role before `start` runs for ANY of
  # them: an `agentType:"rolepod:"` in the JSON would only surface as a
  # mid-run agent-type error inside the fleet script, well after worktrees
  # exist — and a task refused for having no role must never get a
  # worktree, same as a held-back one. Checking this mid-loop (task 1
  # starts, then task 2's empty role aborts the run) would strand task 1's
  # just-created worktree unreported, exactly the "in flight" on a later
  # rerun this fix is meant to prevent.
  for n in $keep_ids; do
    role="$(printf '%s\n' "$rows" | awk -F"$ROW_FS" -v want="$n" '$1==want{print $2; exit}')"
    if [ -z "$role" ]; then
      echo "ticket: fleet: Task $n has no Owner role — refusing (fail-closed)" >&2
      exit 1
    fi
  done

  for n in $keep_ids; do
    role="$(printf '%s\n' "$rows" | awk -F"$ROW_FS" -v want="$n" '$1==want{print $2; exit}')"
    if [ -n "$base" ]; then
      start_out="$(cmd_start "$plan_abs" "$n" --base "$base")"
    else
      start_out="$(cmd_start "$plan_abs" "$n")"
    fi
    start_rc=$?
    if [ "$start_rc" -ne 0 ]; then
      echo "ticket: fleet: start failed for Task $n" >&2
      if [ -n "$started_rows" ]; then
        rollback_worktrees "$repo_root" "$pre_branches" "$started_rows"
      fi
      exit 1
    fi
    handoff="$(printf '%s\n' "$start_out" | sed -n '1p' | awk '{print $1}')"
    wt2="$(printf '%s\n' "$start_out" | sed -n '1p' | awk '{print $2}')"
    # Only a worktree this run created is ever rolled back — `start` also
    # reprints one that already existed (no handoff, so not seen as in flight).
    if ! printf '%s\n' "$wt_snapshot" | grep -qxF "worktree $wt2"; then
      started_rows="$started_rows$n$ROW_FS$wt2
"
    fi
    revlist="$(brief_reviewers "$handoff")"
    entry="$(printf '{"n":%s,"brief":"%s","worktree":"%s","role":"%s","reviewers":%s}' \
      "$n" "$(json_escape "$handoff")" "$(json_escape "$wt2")" "$(json_escape "$role")" \
      "$(printf '%s\n' "$revlist" | reviewers_json_array)")"
    if [ "$first" -eq 1 ]; then tasks_json="$entry"; first=0
    else tasks_json="$tasks_json,$entry"; fi
  done

  # Every ready task was already in flight — nothing started, no JSON.
  if [ -z "$tasks_json" ]; then
    for n in $inflight_ids; do
      echo "in flight — skipped: Task $n"
    done
    return 0
  fi

  printf '{"scriptPath":"%s","args":{"tasks":[%s]}}\n' "$(json_escape "$script_path")" "$tasks_json"
  echo "launch: Workflow({scriptPath, args}) on the CLI with the workflow tool — one launch builds + reviews every task above"
  for n in $inflight_ids; do
    echo "in flight — skipped: Task $n"
  done
  if [ -n "$held_ids" ]; then
    echo "held back (--max $max): $(task_list "$held_ids")"
  fi
}

# ── dispatch ─────────────────────────────────────────────────────────────

SUB="${1:-}"
if [ -z "$SUB" ]; then usage >&2; exit 2; fi
shift || true

case "$SUB" in
  start) cmd_start "$@" ;;
  integrate) cmd_integrate "$@" ;;
  finish) cmd_finish "$@" ;;
  log) cmd_log "$@" ;;
  fleet) cmd_fleet "$@" ;;
  *) echo "ticket: unknown subcommand: $SUB" >&2; usage >&2; exit 2 ;;
esac
