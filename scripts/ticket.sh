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
#     "Agent:" line, for `finish` to report back later).
#     Re-running against an existing worktree reprints the same two lines
#     and changes nothing else.
#
#   rolepod-ticket integrate <worktree> --brief <file> [--pre '<cmd>'] [--gate '<cmd>']
#     Refuses an ambiguous worktree (unmerged commits + a dirty tree).
#     Runs --pre, ff-merges the base into the worktree branch, stages
#     everything except docs/rolepod/, then runs the brief's Command, its
#     Proof command (if any) and --gate — one "ok" or a <=15-line failing
#     tail per step, first failure exits non-zero. On success prints the
#     cached diff stat, any reviewer verdict newer than the worktree, and
#     the exact `git -C <worktree> commit` command. Never commits itself.
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
#     file besides the Lead's own editor.
#
#   rolepod-ticket fleet <plan> [--base <branch>]
#     On the one CLI with a workflow tool: for every task whose Blocked-by
#     tasks are all done and whose Owner is a role (not Lead), runs `start`
#     and reads its brief's "## Reviewers" line, then prints ONE JSON object
#     {scriptPath, args} for scripts/ticket-fleet.js (args.tasks =
#     [{n, brief, worktree, role, reviewers}]) plus one line on how to
#     launch it. No ready role-owned task: says so, exit 0.
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
  rolepod-ticket fleet <plan> [--base <branch>]
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

# I3: the brief FILE is the only thing read here — never plan-lint's
# internals — so this script stays correct whether or not the "## Proof"
# section exists yet.
extract_command() { # $1 = brief file
  first_backtick "$(section_body "$1" '## Command')"
}

extract_proof_command() { # $1 = brief file — line 2's backticked span, optional
  local body line2
  body="$(section_body "$1" '## Proof')"
  [ -n "$body" ] || return 0
  line2="$(printf '%s\n' "$body" | sed -n '2p')"
  [ -n "$line2" ] || return 0
  first_backtick "$line2"
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
  return "$rc"
}

# The owner agent name, when the brief that names this worktree recorded one
# (an "Agent: <name>" line — optional; most briefs will have none). Matched
# by the EXACT basename of the brief's own "## Worktree" path, never a
# substring scan of the file — "-t1" is a literal substring of "-t11", so a
# text-contains check would resolve Task 1's worktree to Task 11's brief
# (or vice versa) whenever both exist side by side.
find_owner_agent() { # $1 = main root, $2 = worktree (absolute)
  local dir base f agent wtline wtcmd path pbase
  dir="$1/docs/rolepod/handoffs"
  [ -d "$dir" ] || return 0
  base="$(basename "$2")"
  for f in "$dir"/*.md; do
    [ -f "$f" ] || continue
    wtline="$(section_body "$f" '## Worktree' | grep -m1 'git worktree add')"
    [ -n "$wtline" ] || continue
    wtcmd="$(first_backtick "$wtline")"
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
# would drop every reference after the first blocker's own aside. NOTE:
# this deliberately diverges from plan-lint.sh's own (advisory-only)
# Blocked-by graph check, which strips from the first "(" to end of line —
# fine for its one worked example ("none (T3 could gate…)") but on a real
# multi-blocker aside (this plan's own Task 5: "Task 1 (...), Task 3 (...),
# Task 4 (...)") it resolves only the first reference. plan-lint.sh is out
# of this task's Files allowed; `fleet` cannot ship on its narrower parse
# without risking a task dispatched before its true blockers are done.
plan_task_rows() { # $1 = plan (absolute)
  awk -v fs="$ROW_FS" '
    function trim(x) { sub(/^[[:space:]]+/, "", x); sub(/[[:space:]]+$/, "", x); return x }
    function flush() {
      if (id == "") return
      bv = B
      gsub(/\([^)]*\)/, "", bv)
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

# Role-owned (non-Lead) task ids whose every Blocked-by task is done — the
# one definition of "ready" shared by start's fleet hint below and by
# `fleet` itself, so the two can never disagree on which tasks qualify.
ready_role_tasks() { # $1 = plan (absolute)
  local plan="$1" rows id owner blocked done done_ids=" "
  rows="$(plan_task_rows "$plan")"
  while IFS="$ROW_FS" read -r id owner blocked done; do
    [ -n "$id" ] || continue
    [ "$done" = "1" ] && done_ids="$done_ids$id "
  done <<EOF
$rows
EOF
  local lead_rx='^Lead([[:space:](]|$)'
  while IFS="$ROW_FS" read -r id owner blocked done; do
    [ -n "$id" ] || continue
    # already done (every box in ITS OWN block checked) — nothing left to
    # build; the Blocked-by graph only cares about a done BLOCKER, not this.
    [ "$done" = "1" ] && continue
    if [[ "$owner" =~ $lead_rx ]] || [[ "$owner" == *"(Lead self-do)"* ]]; then
      continue
    fi
    local ok=1 bid oldifs
    if [ -n "$blocked" ]; then
      oldifs="$IFS"; IFS=','
      for bid in $blocked; do
        case "$done_ids" in *" $bid "*) : ;; *) ok=0 ;; esac
      done
      IFS="$oldifs"
    fi
    [ "$ok" -eq 1 ] && printf '%s\n' "$id"
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
      --base) base="${2:-}"; shift 2 ;;
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
  plan_slug="$(basename "$plan_abs" .md)"
  plan_slug="$(printf '%s' "$plan_slug" | sed -E 's/-[0-9]{4}-[0-9]{2}-[0-9]{2}$//')"
  handoff_dir="$repo_root/docs/rolepod/handoffs"
  mkdir -p "$handoff_dir"
  handoff="$handoff_dir/${plan_slug}-t${n}-owner.md"
  local agent_name agent_line
  agent_name="owner-${plan_slug}-t${n}"
  agent_line="Agent: $agent_name"
  if [ ! -f "$handoff" ] || [ "$(cat "$handoff" 2>/dev/null)" != "$brief_out"$'\n'"$agent_line" ]; then
    printf '%s\n%s\n' "$brief_out" "$agent_line" > "$handoff"
  fi

  local wtline wtcmd branch wtpath wtparent wt_abs
  wtline="$(section_body "$handoff" '## Worktree' | grep -m1 'git worktree add')"
  wtcmd="$(first_backtick "$wtline")"
  [ -n "$wtcmd" ] || { echo "ticket: start: no worktree command found in $handoff" >&2; exit 2; }
  branch="$(printf '%s\n' "$wtcmd" | awk '{print $5}')"
  wtpath="$(printf '%s\n' "$wtcmd" | awk '{print $6}')"
  [ -n "$branch" ] && [ -n "$wtpath" ] || { echo "ticket: start: could not parse worktree command: $wtcmd" >&2; exit 2; }

  wtparent="$(cd "$repo_root/$(dirname "$wtpath")" 2>/dev/null && pwd)"
  [ -n "$wtparent" ] || { echo "ticket: start: could not resolve the worktree path from $wtpath" >&2; exit 2; }
  wt_abs="$wtparent/$(basename "$wtpath")"

  if git -C "$repo_root" worktree list --porcelain 2>/dev/null | grep -qF "worktree $wt_abs"; then
    : # existing worktree — idempotent, nothing to create
  else
    local add_out
    # A branch left behind by a manual `worktree remove` (the branch itself
    # was never deleted) needs a plain add, not -b — otherwise git's own
    # multi-line "branch already exists" error breaks the one-line-message rule.
    if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch"; then
      add_out="$(git -C "$repo_root" worktree add "$wt_abs" "$branch" 2>&1)"
    else
      add_out="$(git -C "$repo_root" worktree add -b "$branch" "$wt_abs" "$base" 2>&1)"
    fi
    if [ $? -ne 0 ]; then
      printf '%s\n' "$add_out" >&2
      exit 1
    fi
  fi

  printf '%s %s\n' "$handoff" "$wt_abs"
  printf 'agent: %s\n' "$agent_name"

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
      --brief) brief="${2:-}"; shift 2 ;;
      --pre) pre="${2:-}"; shift 2 ;;
      --gate) gate="${2:-}"; shift 2 ;;
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

  local cmd_str proof_str
  cmd_str="$(extract_command "$brief")"
  proof_str="$(extract_proof_command "$brief")"

  run_step "command" "$cmd_str" "$wt_root" || exit $?
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

  printf 'git -C "%s" commit -m "<subject>"\n' "$wt_root"
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
      --sha) sha="${2:-}"; shift 2 ;;
      --note) note="${2:-}"; shift 2 ;;
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
}

# ── fleet ────────────────────────────────────────────────────────────────

cmd_fleet() {
  local plan="${1:-}"; shift || true
  local base=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --base) base="${2:-}"; shift 2 ;;
      *) echo "ticket: fleet: unknown arg: $1" >&2; exit 2 ;;
    esac
  done
  if [ -z "$plan" ] || [ ! -f "$plan" ]; then usage >&2; exit 2; fi

  local plan_dir plan_abs repo_root script_path
  plan_dir="$(cd "$(dirname "$plan")" && pwd)"
  plan_abs="$plan_dir/$(basename "$plan")"
  repo_root="$(git -C "$plan_dir" rev-parse --show-toplevel 2>/dev/null)"
  [ -n "$repo_root" ] || { echo "ticket: fleet: not inside a git repo: $plan_abs" >&2; exit 2; }

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

  local rows n role start_out start_rc handoff wt_abs revlist entry tasks_json="" first=1
  rows="$(plan_task_rows "$plan_abs")"
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    if [ -n "$base" ]; then
      start_out="$(cmd_start "$plan_abs" "$n" --base "$base")"
    else
      start_out="$(cmd_start "$plan_abs" "$n")"
    fi
    start_rc=$?
    if [ "$start_rc" -ne 0 ]; then
      echo "ticket: fleet: start failed for Task $n" >&2
      exit 1
    fi
    handoff="$(printf '%s\n' "$start_out" | sed -n '1p' | awk '{print $1}')"
    wt_abs="$(printf '%s\n' "$start_out" | sed -n '1p' | awk '{print $2}')"
    role="$(printf '%s\n' "$rows" | awk -F"$ROW_FS" -v want="$n" '$1==want{print $2; exit}')"
    # Fail closed on an empty role: an `agentType:"rolepod:"` in the JSON
    # would only surface as a mid-run agent-type error inside the fleet
    # script, well after this worktree (and any siblings before it) exist.
    if [ -z "$role" ]; then
      echo "ticket: fleet: Task $n has no Owner role — refusing (fail-closed)" >&2
      exit 1
    fi
    revlist="$(brief_reviewers "$handoff")"
    entry="$(printf '{"n":%s,"brief":"%s","worktree":"%s","role":"%s","reviewers":%s}' \
      "$n" "$(json_escape "$handoff")" "$(json_escape "$wt_abs")" "$(json_escape "$role")" \
      "$(printf '%s\n' "$revlist" | reviewers_json_array)")"
    if [ "$first" -eq 1 ]; then tasks_json="$entry"; first=0
    else tasks_json="$tasks_json,$entry"; fi
  done <<EOF
$ready
EOF

  printf '{"scriptPath":"%s","args":{"tasks":[%s]}}\n' "$(json_escape "$script_path")" "$tasks_json"
  echo "launch: Workflow({scriptPath, args}) on the CLI with the workflow tool — one launch builds + reviews every task above"
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
