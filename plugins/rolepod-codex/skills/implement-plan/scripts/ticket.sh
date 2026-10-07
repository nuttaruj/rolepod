#!/bin/bash
# ticket.sh — deterministic ticket-loop helper (spec: lead-cost-no-pause
# 2026-09-22, architecture A). Moves the Lead's per-task mechanics (worktree,
# spot-check, bookkeeping) into one CLI-neutral tool so a ticket loop costs
# the Lead a handful of calls instead of ~35. Lives in this skill's
# (implement-plan) `scripts/` folder (v2.179.0 — no PATH launcher is
# installed; invoke it by its resolved path, e.g. `bash <this skill's
# folder>/scripts/ticket.sh start ...`).
#
# Usage:
#   ticket.sh start <plan> <N> [--base <branch>]
#     plan-lint the plan (FAIL stops here), write Task N's brief to
#     docs/rolepod/handoffs/<plan-slug>-tN-owner.md, create the worktree +
#     branch the brief's own "## Worktree" line names (off <base>, default
#     the current branch), print "<brief-path> <worktree-path>" then a
#     second line "agent: <name>" (the name recorded in the brief's own
#     "Agent:" line, for `finish` to report back later), then a third line
#     "ship: <the commit -> finish -> log chain>" for the Lead to paste once
#     the task is done.
#     Also records the base checkout (the plan's own) in the task branch's
#     git config, for integrate/finish. Re-running against an existing
#     worktree reprints the same three lines and re-records the base.
#
#   ticket.sh integrate <worktree> --brief <file> [--gate '<cmd>']
#     Refuses an ambiguous worktree (unmerged commits + a dirty tree).
#     The base is the checkout `start` recorded (else the first-listed
#     worktree). ff-merges the base into the worktree branch,
#     stages everything except docs/rolepod/, then runs the brief's Proof
#     command (if any) and --gate — one "ok" or a <=15-line failing tail per step,
#     first failure exits non-zero (the owner already ran the brief's
#     Command; integrate never re-runs it). On success prints the cached
#     diff stat, the VERDICT lines of this task's review reports, and the same
#     ship chain `start` printed, from `git -C <worktree> commit` on. Never
#     commits itself.
#
#   ticket.sh finish <worktree>
#     Refuses a dirty worktree or one whose branch cannot ff-merge (base is
#     not an ancestor of its HEAD — nothing safely mergeable). Otherwise
#     ff-merges the branch into the base checkout (as for integrate),
#     removes + prunes the worktree, deletes the branch, prints
#     "close: <agent name or (unrecorded)>".
#
#   ticket.sh log <plan> <N> --sha <sha> --note '<text>'
#     Flips every `- [ ]` inside Task N's block to `- [x]` and appends one
#     bullet under "## Changes during build". The only writer of the plan
#     file besides the Lead's own editor. Then names every not-done task
#     whose Blocked-by list names N and is now fully done ("ready now: Task
#     a (<owner>), ..."). When the last task of a track is done, also prints
#     "track <id> done — review: <base>...<head>" plus the track-end
#     instruction, and writes that range (generated files left out) to
#     .rolepod/evidence/review/<feature>-<id>.diff, naming it on the same
#     line ("; lens diff: <path>") so the review lenses get the diff as a
#     file, not a shell. The next line is `Review:` — the R3 cell of
#     `plan-lint.sh --review-set` for the session mode — then `Track end:`
#     names who runs `convening-code-review`. A write failure never fails log — the range still
#     prints, just without the path. Idempotent, same as the checkbox flip.
#     Tracks: listed in `## Tracks`; without it a Parallel plan makes each
#     task its own track (id = the task number) and a Sequential plan is one
#     track `plan` (id `plan`, diff <feature>-plan.diff). With no track
#     worktree the commits sit on the base checkout, so <base> is the parent
#     of the track's first logged commit.
#
#   ticket.sh log <plan> <N> --start
#     Marks Task N `running` (its Owner role, since HH:MM) in the plan's
#     `## Status` block; `log --sha` rewrites it `done` plus the sha.
#   ticket.sh status <plan>
#     Prints the Status block — `N/M done · K running`, one row per task
#     (done / running / `waits on <ids>` / todo) — and writes nothing. The
#     writer puts `## Status` before the plan's first `## ` heading.
#
#   ticket.sh review-diff start <name> [-- <path>...]
#     In the current git checkout: `git add -A` then `git reset -q -- docs/rolepod`
#     (docs never stage; with `-- <path>...`: only
#     those paths, new files under them included, nothing else staged; a path
#     is literal and relative to the checkout root — a missing one is skipped
#     with a stderr note, none left, or a ":"/"."/".."/absolute one -> exit 2,
#     never a whole-tree stage); writes
#     .rolepod/evidence/review/<name>.diff = `git diff --cached --stat` then
#     `git diff --cached -U10`, both over `-- <paths or .>` minus the one
#     exclude list (review_excludes: docs/rolepod, lockfiles, plus one git
#     pathspec per line of <git-root>/.rolepod/review-exclude, read from the
#     checkout or, absent there, the base checkout; blank and # lines skipped);
#     prints `diff: <absolute path>` then `H1: <git write-tree>`. No path list
#     -> whole tree and a third line `limitation: whole-tree diff — ...`. An
#     empty diff -> "ticket: review-diff: empty diff" on stderr, exit 1, no file.
#   ticket.sh review-diff delta <name> <H1-tree> <k> [-- <path>...]
#     <k> is 2, 3 or 4; `git add -A` then `git reset -q -- docs/rolepod` (or
#     `-- <path>...` only, staged as named); H2 = `git
#     write-tree`; writes
#     .rolepod/evidence/review/<name>-r<k>.diff = `git diff <H1-tree> <H2> -U10`
#     over the same pathspec; prints `diff: <absolute path>` then `H2: <tree>`.
#     An <H1-tree> that is not a tree object (a commit sha too) -> exit 2. A
#     delta with no change since <H1-tree> -> "empty diff", exit 1, no file.
#     <name> matches [A-Za-z0-9._-]+; a bad name, bad k or a missing argument
#     -> one usage line on stderr, exit 2. The tree stays staged; never commits,
#     stashes, resets or checks out.
#
# Tracks (spec worktree-track-2026-09-30): a task whose brief names a track
# worktree reuses it when it exists (the 2nd+ task of the track) and records
# the plan path in `branch.<b>.rolepod-plan`; its ship line is `integrate ->
# git commit -> log` with NO finish, and integrate accepts the track's earlier
# task commits ahead of base. A single-track plan (no ## Tracks, Sequential)
# whose first task starts while another session holds a live lock on the base
# checkout runs in one `<feature>/plan` worktree; with no live lock and no plan
# worktree it stays on the base checkout (the --main brief, no worktree, one
# "on the base checkout: ..." line instead of the ship line). A plan whose
# `## Parallel layout` does not START with "Sequential" keeps per-task
# worktrees. `finish` refusing a base that moved names the merge fix. `log` of a track's last task
# prints "track <id> done — review: <base>..<head>" and writes
# .rolepod/evidence/review/<feature>-<id>.diff; `finish <worktree>` (once, at
# track end) merges the track and names any fan-in task now ready.
#
# `start` holds a per-plan lock (<git-common-dir>/ticket-<plan-slug>.lock)
# for its run: a second one on the same plan refuses until the first ends;
# a lock whose process is gone is taken over.
#
# bash 3.2 safe, set -u safe, no network, fail-closed with one-line errors.
set -uo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
SELF_PATH="$SELF_DIR/$(basename "$0")"
LINT="$SELF_DIR/../../write-plan/scripts/plan-lint.sh"

# docs-mode.sh sits beside this script in a rendered tree; only the source layout
# (core/skills/implement-plan/scripts) falls back to hooks/lib.
DOCS_MODE=""
if [ -f "$SELF_DIR/docs-mode.sh" ]; then DOCS_MODE="$SELF_DIR/docs-mode.sh"
else case "$SELF_DIR" in */core/skills/implement-plan/scripts) [ -f "$SELF_DIR/../../../../hooks/lib/docs-mode.sh" ] && DOCS_MODE="$SELF_DIR/../../../../hooks/lib/docs-mode.sh" ;; esac; fi

# The stage that never drags docs: stage the tree, then unstage docs/rolepod only.
# Never `git rm --cached` on the real index.
stage_no_docs() { # $1 = checkout root
  git -C "$1" add -A && git -C "$1" reset -q -- docs/rolepod
}

# plan_task_rows' internal field separator — never a tab: `read` treats tab
# as "IFS whitespace" regardless of what IFS is set to, so it COLLAPSES
# adjacent tabs instead of yielding an empty field for a task with no
# Blocked-by, silently shifting every field after it.
ROW_FS=$'\x1f'

# Fence rule (plan-fence contract, 2026-09-28): the canonical awk
# fence text every plan-reading pass in this script includes verbatim (no
# shared lib across scripts — declined earlier; each script that needs it
# carries its own copy — only this shell variable's name is script-local).
# A line whose text, after at most 3 leading spaces, starts with 3+
# backticks or 3+ tildes opens a fence; it closes at the first later line
# that, after at most 3 leading spaces, repeats the same character at
# least as many times with only spaces/tabs after it. An unclosed fence
# runs to end of file. No `{n,m}` interval expression (mawk has none) —
# fence length is counted with a for-loop instead. A caller places
# `{ if (fenceline($0)) { <literal action>; next } }` as its FIRST rule so
# a fenced line never reaches the patterns below it. A pass whose OUTPUT a
# caller then pattern-matches (resolve_contract's Parallel-layout read,
# section_body, the bullet-dedupe scan) skips a fenced line entirely
# (`next`, print nothing); only a log write pass — one that copies the
# plan back out — prints it unchanged.
FENCE_FN='
function leadspaces(s,    i, c, n) {
  n = 0
  for (i = 1; i <= length(s); i++) {
    c = substr(s, i, 1)
    if (c == " ") n++
    else break
  }
  return n
}
function fenceline(line,    lead, rest, ch, n, i, c, after) {
  if (FNR == 1) { infence = 0; fencechar = ""; fencelen = 0; fenceopen = 0 }
  sub(/\r$/, "", line)
  lead = leadspaces(line)
  rest = substr(line, lead + 1)
  if (infence) {
    if (lead <= 3) {
      ch = substr(rest, 1, 1)
      if (ch == fencechar) {
        n = 0
        for (i = 1; i <= length(rest); i++) { c = substr(rest, i, 1); if (c == fencechar) n++; else break }
        if (n >= fencelen) {
          after = substr(rest, n + 1)
          gsub(/[ \t]/, "", after)
          if (after == "") { infence = 0; fencechar = ""; fencelen = 0; fenceopen = 0 }
        }
      }
    }
    return 1
  }
  if (lead <= 3) {
    ch = substr(rest, 1, 1)
    if (ch == "`" || ch == "~") {
      n = 0
      for (i = 1; i <= length(rest); i++) { c = substr(rest, i, 1); if (c == ch) n++; else break }
      if (n >= 3) { fencechar = ch; fencelen = n; infence = 1; fenceopen = FNR; return 1 }
    }
  }
  return 0
}
function fence_is_open() { return infence }
function fence_open_line() { return fenceopen }
'

usage() {
  cat <<'EOF'
usage:
  ticket.sh start <plan> <N> [--base <branch>]
  ticket.sh integrate <worktree> --brief <file> [--gate '<cmd>']
  ticket.sh finish <worktree>
  ticket.sh log <plan> <N> --sha <sha> --note '<text>'
  ticket.sh log <plan> <N> --start
  ticket.sh status <plan>
  ticket.sh review-diff start <name> [-- <path>...]
  ticket.sh review-diff delta <name> <H1-tree> <k> [-- <path>...]
  (review-diff excludes: docs/rolepod, lockfiles, plus .rolepod/review-exclude lines)
EOF
}

# ── helpers ──────────────────────────────────────────────────────────────

# The base checkout of worktree $1 — the checkout its task was STARTED from:
# the plan's own checkout (where `start` ran and the handoffs live), which
# may be a linked worktree on a feature branch — not the Lead's cwd.
# `start` records it in the task branch's git config (shared by every
# worktree, gone with `branch -d`). A record that is no longer a worktree
# → empty (the callers fail closed). No record (a worktree made without
# `start`) → the first-listed worktree, parsed by stripping the "worktree "
# prefix so a path with a space survives.
base_root_of() {
  local branch cfg list
  list="$(git -C "$1" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')"
  branch="$(git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  cfg=""
  [ -n "$branch" ] && cfg="$(git -C "$1" config --get "branch.$branch.rolepod-base-root" 2>/dev/null)"
  if [ -z "$cfg" ]; then
    printf '%s' "$list" | head -n 1
  elif printf '%s\n' "$list" | grep -qxF -- "$cfg"; then
    printf '%s' "$cfg"
  fi
}

# The one review-diff exclude list for checkout "$1": git pathspecs, one per
# line, used verbatim after `-- <paths or .>` by review-diff start / delta and
# the track-end lens diff. Defaults (docs/rolepod, lockfiles) plus one
# `:!<line>` per line of <root>/.rolepod/review-exclude (blank and # lines
# skipped); absent there → the base checkout's file (a track worktree sees the
# base's), absent in both → defaults only. No project path lives in this script.
review_excludes() {
  local root="$1" cfg base line
  printf '%s\n' ':!docs/rolepod' ':!*.lock' ':!package-lock.json' ':!pnpm-lock.yaml'
  cfg="$root/.rolepod/review-exclude"
  if [ ! -f "$cfg" ]; then
    base="$(base_root_of "$root")"
    [ -n "$base" ] && cfg="$base/.rolepod/review-exclude"
  fi
  [ -f "$cfg" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%"${line##*[![:space:]]}"}"
    case "$line" in ''|'#'*) continue ;; esac
    printf ':!%s\n' "$line"
  done < "$cfg"
  return 0
}

# Lines of section "$2" (an exact "## Heading" string) inside file "$1" —
# fence-aware: a fenced "## Heading" look-alike never opens or closes the
# section, and a fenced line is skipped outright — this output is always
# pattern-matched by a caller (a backticked command, a Proof line), never
# copied back out, so a fenced line never enters it.
# Heading rule = plan-lint.sh's: case-sensitive, trailing whitespace / CR
# ignored ("## Tracks" is `^## Tracks[[:space:]]*$` there); "$3" =
# $HEADING_PREFIX (any non-empty value works) also takes a suffix after the
# name, as plan-lint reads "## Parallel layout".
HEADING_PREFIX=prefix
section_body() { # $1 = file, $2 = "## Heading", $3 = $HEADING_PREFIX or empty
  awk -v h="$2" -v pfx="${3:-}" "$FENCE_FN"'
    { if (fenceline($0)) next }
    { hl = $0; sub(/[[:space:]]+$/, "", hl) }
    hl == h || (pfx != "" && index($0, h) == 1) { f = 1; next }
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
# -YYYY-MM-DD date stripped. What cmd_start derives the handoff path + agent
# name from — kept in one place so every caller reads the same slug.
plan_slug_of() { # $1 = plan (absolute)
  local slug
  slug="$(basename "$1" .md)"
  printf '%s' "$slug" | sed -E 's/-[0-9]{4}-[0-9]{2}-[0-9]{2}$//'
}

# The plan's feature name — its basename with the .md extension and a LEADING
# YYYY-MM-DD- date stripped (worktree-track spec: branch <feature>/<id>-<slug>,
# plan worktree <feature>/plan).
plan_feature_of() { # $1 = plan (absolute)
  basename "$1" .md | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//'
}

# True (rc 0) when the plan has a `## Tracks` section with a body.
plan_has_tracks() { # $1 = plan
  [ -n "$(section_body "$1" '## Tracks' | grep -v '^[[:space:]]*$')" ]
}

# True (rc 0) when the plan's `## Parallel layout` starts with "Sequential".
plan_is_sequential() { # $1 = plan
  section_body "$1" '## Parallel layout' "$HEADING_PREFIX" | grep -v '^[[:space:]]*$' | head -n 1 | grep -q '^Sequential'
}

# One row per task: "<id><ROW_FS><track>" off each task's `- **Track:** X`
# field (first one wins); a task with no Track field has no row.
plan_task_tracks() { # $1 = plan
  awk -v fs="$ROW_FS" "$FENCE_FN"'
    { if (fenceline($0)) next }
    /^### (Task ?|T)[0-9]+/ { id = $0; sub(/^### (Task ?|T)/, "", id); sub(/[^0-9].*$/, "", id); seen = 0; next }
    /^## / { id = ""; next }
    id != "" && !seen && $0 ~ /^[[:space:]]*-([[:space:]]*\[[ xX]\])?[[:space:]]*\*\*Track:\*\*/ {
      v = $0; sub(/.*\*\*Track:\*\*[[:space:]]*/, "", v); sub(/[[:space:]].*$/, "", v); gsub(/`/, "", v)
      if (v != "") { printf "%s%s%s\n", id, fs, v; seen = 1 }
    }
  ' "$1"
}

# The track of task "$2" in track table "$1" (plan_task_tracks output).
track_of() { # $1 = table, $2 = task id
  printf '%s\n' "$1" | awk -F "$ROW_FS" -v want="$2" '($1 "") == (want "") { print $2; exit }'
}

# Every sha `log` recorded ("- Task N (`sha`): ..." under ## Changes during
# build), one per line in log order; "$2" = one task id, empty = every task.
# The one scan behind task_logged_sha, the track's first commit and integrate's
# named-commit check.
logged_shas() { # $1 = plan, $2 = task id or empty
  awk -v want="$2" "$FENCE_FN"'
    { if (fenceline($0)) next }
    /^## Changes during build/ { insec = 1; next }
    insec && /^## / { exit }
    insec && (want == "" ? $0 ~ /^- Task [0-9]+ \(`/ : index($0, "- Task " want " (`") == 1) && match($0, /`[^`]+`/) { print substr($0, RSTART + 1, RLENGTH - 2) }
  ' "$1"
}

# The sha `log` recorded for task "$2", empty when none.
task_logged_sha() { # $1 = plan, $2 = task id
  logged_shas "$1" "$2" | head -n 1
}

own_ancestor_pids() { # prints " <pid> <pid> ... " — $$ and every ancestor
  local p="$$" out=" " i=0
  while [ -n "$p" ] && [ "$p" -gt 1 ] 2>/dev/null && [ "$i" -lt 32 ]; do
    out="$out$p "
    p="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d '[:space:]')"
    i=$((i + 1))
  done
  printf '%s' "$out"
}

# True (rc 0) when another session holds a live lock on checkout "$1": a
# *.lock under $HOME/.rolepod/session-locks/<first 16 hex of sha256 of the
# path>/ younger than 1800 s (the rule hooks/session-lifecycle.sh writes and
# prunes by). This session's own lock is skipped: its id in
# CLAUDE_CODE_SESSION_ID / ROLEPOD_SESSION_ID first, else a lock whose line 2
# (the CLI pid session-lifecycle.sh recorded) is one of this process's
# ancestors — no env var needed on any CLI.
foreign_live_lock() { # $1 = checkout (git toplevel)
  local hash dir lock now mtime own lpid ancestors=""
  hash="$(printf '%s' "$1" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | awk '{print $1}' | head -c 16)"
  [ -n "$hash" ] || return 1
  dir="${HOME:-}/.rolepod/session-locks/$hash"
  [ -d "$dir" ] || return 1
  own="${CLAUDE_CODE_SESSION_ID:-${ROLEPOD_SESSION_ID:-}}"
  now="$(date +%s)"
  for lock in "$dir"/*.lock; do
    [ -f "$lock" ] || continue
    [ -n "$own" ] && [ "$(basename "$lock" .lock)" = "$own" ] && continue
    lpid="$(sed -n '2p' "$lock" 2>/dev/null | tr -d '[:space:]')"
    if [ -n "$lpid" ] && [ "$lpid" -eq "$lpid" ] 2>/dev/null; then
      [ -n "$ancestors" ] || ancestors="$(own_ancestor_pids)"
      case "$ancestors" in *" $lpid "*) continue ;; esac
    fi
    mtime="$(stat -c %Y "$lock" 2>/dev/null || stat -f %m "$lock" 2>/dev/null || echo 0)"
    [ $((now - mtime)) -lt 1800 ] && return 0
  done
  return 1
}

# One `start` per plan at a time. Two overlapping runs against the same
# plan could both create the same worktree/branch. mkdir is the atomic
# test-and-set; the lock sits in the git common dir (never staged, shared
# by every worktree).
TICKET_LOCK=""
take_plan_lock() { # $1 = subcommand, $2 = plan (absolute), $3 = repo root
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
      echo "ticket: $1: another start is running for this plan (pid ${pid:-unknown}) — re-run when it ends; no such process → rm -rf $lock" >&2
      exit 1
    fi
  fi
  echo "$$" > "$lock/pid"
  TICKET_LOCK="$lock"
  trap 'rm -rf "$TICKET_LOCK"' EXIT
}

# The backticked `git worktree add -b <branch> <path> [<base>]` command
# line from a handoff file's own "## Worktree" section — cmd_start parses
# the branch + path out of it, kept in one place so a plan-lint template
# change only needs fixing here.
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

# The task's record file, repo-relative: docs/rolepod/tasks/<plan file name
# without .md>/task-NN.md (NN zero-padded to 2 digits).
task_file_rel() { # $1 = plan, $2 = task number
  printf 'docs/rolepod/tasks/%s/task-%02d.md' "$(basename "$1" .md)" "$((10#$2))"
}

brief_plan_path() { # $1 = brief file
  sed -n '2s/^Plan: \(.*\) · Spec:.*/\1/p' "$1"
}

# One task's review reports (.md) in one reviews dir, at most 10: the files named
# <plan-slug>-task<N>- (the name the brief's Bounds gives the owner); none so named
# (an owner that ignored it) -> the .md files newer than anchor "$4", minus any
# named for ANOTHER task of the plan, so one task never lists a sibling's report.
task_review_reports() { # $1 = reviews dir, $2 = plan slug, $3 = task number, $4 = anchor file
  local out
  [ -d "$1" ] || return 0
  out="$(find "$1" -maxdepth 1 -type f -name "$2-task$((10#$3))-*.md" 2>/dev/null | sort)"
  if [ -z "$out" ] && [ -e "$4" ]; then
    out="$(find "$1" -maxdepth 1 -type f -name '*.md' -newer "$4" 2>/dev/null | grep -Ev "/$2-task[0-9]+-[^/]*\$" | sort)"
  fi
  [ -z "$out" ] || printf '%s\n' "$out" | head -n 10
}

# The commit -> finish -> log tail of the ONE ship chain (spec lean-loop-
# 2026-09-23 Task 2), shared verbatim by `start`'s "ship:" line and
# `integrate`'s own success output. <subject>/<note> stay literal
# placeholders for the Lead to fill; "$(git -C <base> rev-parse --short
# HEAD)" is printed literal too — it runs only when the Lead pastes and
# runs the chain, and reads the base checkout, since `finish` (the step
# before it in the chain) merges the commit there and removes the worktree
# — the caller's own cwd may be neither.
# A task in a track (or a plan worktree) drops `finish` — the Lead runs it
# once, after the track-end review ($5 = "track" or "plan"; empty = per task).
ship_chain_tail() { # $1 = worktree (absolute), $2 = plan (absolute), $3 = task N, $4 = base checkout (absolute), $5 = mode or empty
  local fin="" shabase="$4"
  if [ -z "${5:-}" ]; then
    fin="$(printf "bash '%s' finish '%s' && " "$SELF_PATH" "$1")"
  else
    shabase="$1" # no finish: the commit lives only in the track / plan worktree
  fi
  printf 'git -C '\''%s'\'' commit -m '\''<subject>'\'' && %sbash '\''%s'\'' log '\''%s'\'' %s --sha "$(git -C '\''%s'\'' rev-parse --short HEAD)" --note '\''<note>'\''' \
    "$1" "$fin" "$SELF_PATH" "$2" "$3" "$shabase"
}

# scripts/plan-lint.sh --brief does not auto-resolve the contract path (only
# its non---brief path does, and that file is out of scope for this task) —
# this is the same 5-line lookup duplicated on purpose: a plan's own
# "## Parallel layout" backticked *.md path, resolved against the plan's
# dir, then the repo root.
resolve_contract() { # $1 = plan (absolute), $2 = repo root
  local layout rel plan_dir cand
  layout="$(awk "$FENCE_FN"'
    { if (fenceline($0)) next }
    /^## Parallel layout/{f=1;next} /^## /{f=0} f
  ' "$1")"
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
find_owner_agent() { # $1 = base root, $2 = worktree (absolute)
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
  awk -v fs="$ROW_FS" "$FENCE_FN"'
    { if (fenceline($0)) next }
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
      # A heading line (`#`-led — a non-task "### Notes" subheading, since a
      # real task heading or "## " is already caught above) ends whatever
      # field was open: an Owner or Blocked-by value must never absorb a
      # subheading line that merely sits inside the same block.
      if (line ~ /^#/) { field = ""; next }
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
# "$1" (a plan_task_rows table) — the one done-id lookup ready_now_after
# builds from.
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

# Status block (S1). `log --start` marks a task running (its Owner role and
# since HH:MM); `log --sha` flips it done plus the sha; `status` prints the
# block without writing. The block lives in the plan under `## Status`.
# One "<id><ROW_FS><title>" row per task heading ("### Task N: title").
plan_task_titles() { # $1 = plan (absolute)
  awk -v fs="$ROW_FS" "$FENCE_FN"'
    { if (fenceline($0)) next }
    /^### (Task ?|T)[0-9]+/ {
      id = $0; sub(/^### (Task ?|T)/, "", id); sub(/[^0-9].*$/, "", id)
      t = $0; sub(/^### (Task ?|T)[0-9]+[[:space:]]*[:.—–-]*[[:space:]]*/, "", t)
      sub(/[[:space:]]+$/, "", t)
      printf "%s%s%s\n", id, fs, t
    }
  ' "$1"
}

# "<id><ROW_FS><role, since HH:MM>" for every `running` row of the plan's
# existing `## Status` block.
status_running_rows() { # $1 = plan
  awk -v fs="$ROW_FS" "$FENCE_FN"'
    { if (fenceline($0)) next }
    /^## Status[[:space:]]*$/ { insec = 1; next }
    insec && /^## / { exit }
    insec && /^- Task [0-9]+ — .*: running \([^)]*\)[[:space:]]*$/ {
      id = $0; sub(/^- Task /, "", id); sub(/[^0-9].*$/, "", id)
      d = $0; sub(/^.*: running \(/, "", d); sub(/\)[[:space:]]*$/, "", d)
      printf "%s%s%s\n", id, fs, d
    }
  ' "$1"
}

# The block body: `N/M done · K running`, one row per task. "$2" = a task id
# to mark running now (empty: only rows already running stay running).
status_body() { # $1 = plan, $2 = task id starting or empty
  local plan="$1" start_n="${2:-}" rows titles prior done_ids
  local id owner blocked done title sha detail bid state oldifs wait total=0 ndone=0 nrun=0 lines=""
  rows="$(plan_task_rows "$plan")"
  titles="$(plan_task_titles "$plan")"
  prior="$(status_running_rows "$plan")"
  done_ids="$(done_ids_of "$rows")"
  while IFS="$ROW_FS" read -r id owner blocked done; do
    [ -n "$id" ] || continue
    total=$((total + 1))
    title="$(printf '%s\n' "$titles" | awk -F "$ROW_FS" -v want="$id" '($1 "") == (want "") { print $2; exit }')"
    if [ "$done" = "1" ]; then
      sha="$(task_logged_sha "$plan" "$id")"
      state="done"; [ -z "$sha" ] || state="done (\`$sha\`)"
      ndone=$((ndone + 1))
    else
      detail="$(printf '%s\n' "$prior" | awk -F "$ROW_FS" -v want="$id" '($1 "") == (want "") { print $2; exit }')"
      if [ "$id" = "$start_n" ]; then
        detail="$(printf '%s' "$owner" | sed 's/ *([^)]*)//g'), since $(date +%H:%M)"
      fi
      if [ -n "$detail" ]; then
        state="running ($detail)"
        nrun=$((nrun + 1))
      else
        wait=""
        if [ -n "$blocked" ]; then
          oldifs="$IFS"; IFS=','
          for bid in $blocked; do
            case "$done_ids" in *" $bid "*) : ;; *) wait="${wait:+$wait, }$bid" ;; esac
          done
          IFS="$oldifs"
        fi
        if [ -n "$wait" ]; then state="waits on $wait"; else state="todo"; fi
      fi
    fi
    lines="$lines- Task $id — $title: $state"$'\n'
  done <<EOF
$rows
EOF
  printf '%s/%s done · %s running\n%s' "$ndone" "$total" "$nrun" "$lines"
}

# Writes `## Status` + body "$2" into plan "$1": replaces an existing block in
# place, else goes before the first `## ` heading (end of file when none).
# Fence-aware; a failed pass leaves the plan untouched and returns 1.
status_write() { # $1 = plan, $2 = body
  local plan="$1" body="$2" has="" tmp
  awk "$FENCE_FN"'
    { if (fenceline($0)) next }
    /^## Status[[:space:]]*$/ { f = 1; exit }
    END { exit !f }
  ' "$plan" && has=1
  tmp="$(mktemp "${TMPDIR:-/tmp}/rolepod-ticket-status.XXXXXX")" || return 1
  if TICKET_STATUS_BODY="$body" awk -v has="$has" "$FENCE_FN"'
    function emit() { printf "## Status\n%s\n\n", ENVIRON["TICKET_STATUS_BODY"]; done = 1 }
    { if (fenceline($0)) { if (!skip) print; next } }
    /^## Status[[:space:]]*$/ { if (!done) emit(); skip = 1; next }
    /^## / {
      skip = 0
      if (!done && has == "") emit()
      print; next
    }
    skip { next }
    { print }
    END { if (!done) { print ""; emit() } }
  ' "$plan" > "$tmp" && [ -s "$tmp" ]; then
    cp "$tmp" "$plan"
    rm -f "$tmp"
    return 0
  fi
  rm -f "$tmp"
  return 1
}

# True (rc 0) when Owner field "$1" is the Lead, not a role — log's role
# tally (the Review-readiness count below).
is_lead_owner() { # $1 = owner field
  local owner="$1" lead_rx='^Lead([[:space:](]|$)'
  [[ "$owner" =~ $lead_rx ]] || [[ "$owner" == *"(Lead self-do)"* ]]
}

# True (rc 0) when every comma-separated blocker id in "$1" is present in
# done-id set "$2" (from done_ids_of) — an empty "$1" (no Blocked-by) is
# vacuously done. The one "are its blockers all done" test ready_now_after
# applies, so a re-run can never disagree with itself.
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

# Not-done tasks whose Blocked-by list names task "$2" and whose every
# blocker is now done — the set `log` reports as "just became ready" after
# flipping Task "$2"'s own checkboxes. Any owner, Lead included. One row
# per line: "<id><ROW_FS><owner>".
#
# In a plan with tracks a blocker in ANOTHER track counts only once that
# track is merged (fan-in starts from the merged base): "$3" = the base
# checkout to test that against. "$2" empty = every fan-in candidate (finish).
ready_now_after() { # $1 = plan, $2 = task id just logged (or empty), $3 = base checkout
  local plan="$1" want="$2" root="${3:-}" rows id owner blocked done done_ids tracks
  rows="$(plan_task_rows "$plan")"
  done_ids="$(done_ids_of "$rows")"
  tracks="$(plan_task_tracks "$plan")"
  while IFS="$ROW_FS" read -r id owner blocked done; do
    [ -n "$id" ] || continue
    [ "$done" = "1" ] && continue
    # only a task whose Blocked-by list names $want at all — a task that
    # was already ready for other reasons is not "just became ready" here.
    if [ -n "$want" ]; then
      case ",$blocked," in *",$want,"*) : ;; *) continue ;; esac
    elif ! has_cross_track_blocker "$tracks" "$id" "$blocked"; then
      continue
    fi
    all_blockers_done "$blocked" "$done_ids" || continue
    blockers_merged "$plan" "$root" "$tracks" "$id" "$blocked" || continue
    printf '%s%s%s\n' "$id" "$ROW_FS" "$owner"
  done <<EOF
$rows
EOF
}

# True (rc 0) when a comma-list blocker of task "$2" sits in another track.
has_cross_track_blocker() { # $1 = tracks table, $2 = task id, $3 = blocked csv
  local mine b theirs oldifs="$IFS" hit=1
  mine="$(track_of "$1" "$2")"
  [ -n "$mine" ] || return 1
  IFS=','
  for b in $3; do
    theirs="$(track_of "$1" "$b")"
    [ -n "$theirs" ] && [ "$theirs" != "$mine" ] && hit=0
  done
  IFS="$oldifs"
  return "$hit"
}

# True (rc 0) when every blocker of task "$4" that sits in another track has
# its logged commit inside checkout "$2"'s HEAD (its track merged). No track
# table (a plan without tracks) or no checkout → true.
blockers_merged() { # $1 = plan, $2 = base checkout, $3 = tracks table, $4 = task id, $5 = blocked csv
  local mine b theirs sha oldifs="$IFS" ok=0
  [ -n "$3" ] && [ -n "$2" ] || return 0
  mine="$(track_of "$3" "$4")"
  [ -n "$mine" ] || return 0
  IFS=','
  for b in $5; do
    theirs="$(track_of "$3" "$b")"
    [ -n "$theirs" ] && [ "$theirs" != "$mine" ] || continue
    sha="$(task_logged_sha "$1" "$b")"
    if [ -z "$sha" ] || ! git -C "$2" merge-base --is-ancestor "$sha" HEAD 2>/dev/null; then ok=1; fi
  done
  IFS="$oldifs"
  return "$ok"
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
  [ -f "$LINT" ] || { echo "ticket: start: plan-lint.sh not found at $LINT (the write-plan skill's scripts/)" >&2; exit 2; }

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

  # Worktree mode (worktree-track spec), decided from the plan's structure
  # (never from brief prose) BEFORE the one plan-lint --brief call below.
  # "track": the plan has `## Tracks` and the task carries a `**Track:**`
  # (plan-lint FAILed above for an unlisted one) — the brief names a track
  # worktree shared by the track's tasks (an existing one is reused below).
  # "plan": a single-track plan (no ## Tracks, Sequential layout) whose plan
  # worktree exists already, or whose FIRST task starts while another session
  # holds a live lock on this checkout — the brief names <feature>/plan.
  # "main": the same plan with neither (C4) — the base checkout, no worktree.
  # Anything else keeps the per-task worktree as before.
  local wt_mode="" brief_flag=""
  if plan_has_tracks "$plan_abs"; then
    [ -z "$(track_of "$(plan_task_tracks "$plan_abs")" "$n")" ] || wt_mode="track"
  elif plan_is_sequential "$plan_abs"; then
    local pfeat prepo pwt_abs prows
    pfeat="$(plan_feature_of "$plan_abs")"
    prepo="$(basename "$repo_root" | sed 's/[^A-Za-z0-9._-]/-/g')"
    pwt_abs="$(cd "$repo_root/.." && pwd -P)/${prepo}-wt-${pfeat}"
    prows="$(plan_task_rows "$plan_abs")"
    if git -C "$repo_root" worktree list --porcelain 2>/dev/null | grep -qxF "worktree $pwt_abs" \
      || { [ "$(done_ids_of "$prows")" = " " ] && foreign_live_lock "$repo_root"; }; then
      wt_mode="plan"; brief_flag="--plan-worktree"
    else
      wt_mode="main"; brief_flag="--main"
    fi
  fi

  local brief_out brief_args
  brief_args=("$n" "$plan_abs")
  [ -z "$contract" ] || brief_args+=("$contract")
  [ -z "$brief_flag" ] || brief_args+=("$brief_flag")
  if ! brief_out="$(bash "$LINT" --brief "${brief_args[@]}" 2>&1)"; then
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

  # The task's own record file (handoff board off the plan): created once.
  local task_file task_title
  task_file="$repo_root/$(task_file_rel "$plan_abs" "$n")"
  if [ ! -f "$task_file" ]; then
    task_title="$(printf '%s\n' "$brief_out" | sed -n '1s/^# Task [0-9][0-9]*: *//p')"
    mkdir -p "$(dirname "$task_file")" 2>/dev/null
    printf '# Task %s — %s\nBase: %s\n\n## Decision brief\n\n### Change\n- `<path>` — <what changed>\n\n### Tests added / changed\n- `<path>` — <what the test asserts>\n\n### Commands\n- `<command>` — <result and the proof lines>\n\n### Scope check\n<the diff matches the task; deferred ideas listed, not acted on>\n\n### Concerns\n<correctness, scope or observation doubts for the Lead, or None>\n\n### Author fix closure\n- Delta H1→H2: <changed paths + delta hash>\n- H2: <verified snapshot after the fixes>\n- Re-check: <report path of the Fix-verify re-check at H2, or `none — no BLOCKER / MAJOR fixed`>\n\n### Owner status\nCOMPLETED | PARTIAL | BLOCKED\n\n## Verify status\nVERIFIED | PARTIAL | UNVERIFIED\n\n## Handoff\n\n## Reviews\n\n## Lead notes\n' \
      "$n" "$task_title" "$(git -C "$repo_root" rev-parse HEAD 2>/dev/null)" > "$task_file" \
      || { echo "ticket: start: cannot write the task file $task_file" >&2; exit 1; }
  fi

  if [ "$wt_mode" = "main" ]; then
    printf '%s %s\n' "$handoff" "$repo_root"
    printf 'agent: %s\n' "$agent_name"
    echo "on the base checkout: stage with git add -A && git reset -q -- docs/rolepod, the Lead commits with the commit check, then ticket.sh log <plan> <N> --sha <sha>"
    printf 'task file: %s\n' "$task_file"
    return 0
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

  # integrate / finish work against this checkout, not the first-listed one.
  if ! git -C "$repo_root" config "branch.$branch.rolepod-base-root" "$repo_root" >/dev/null 2>&1; then
    echo "ticket: start: cannot record the base checkout for $branch — re-run start" >&2
    exit 1
  fi

  # A track / plan worktree: the plan path rides on the branch (integrate
  # reads it to tell a track worktree from a per-task one).
  if [ -n "$wt_mode" ] && ! git -C "$repo_root" config "branch.$branch.rolepod-plan" "$plan_abs" >/dev/null 2>&1; then
    echo "ticket: start: cannot record the plan for $branch — re-run start" >&2
    exit 1
  fi

  printf '%s %s\n' "$handoff" "$wt_abs"
  printf 'agent: %s\n' "$agent_name"
  printf 'ship: bash '\''%s'\'' integrate '\''%s'\'' --brief '\''%s'\'' --gate '\''<commit gate>'\'' && %s\n' \
    "$SELF_PATH" "$wt_abs" "$handoff" "$(ship_chain_tail "$wt_abs" "$plan_abs" "$n" "$repo_root" "$wt_mode")"
  printf 'task file: %s\n' "$task_file"
}

# ── integrate ────────────────────────────────────────────────────────────

cmd_integrate() {
  local wt="${1:-}"; shift || true
  local brief="" gate=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --brief) need_val integrate --brief $#; brief="$2"; shift 2 ;;
      --gate) need_val integrate --gate $#; gate="$2"; shift 2 ;;
      *) echo "ticket: integrate: unknown arg: $1" >&2; exit 2 ;;
    esac
  done
  if [ -z "$wt" ] || [ ! -d "$wt" ] || [ -z "$brief" ] || [ ! -f "$brief" ]; then
    usage >&2; exit 2
  fi

  local wt_root base_root base_branch dirty ahead ahead_rc
  wt_root="$(cd "$wt" && pwd)"
  base_root="$(base_root_of "$wt_root")"
  [ -n "$base_root" ] || { echo "ticket: integrate: cannot resolve the base checkout for $wt_root" >&2; exit 2; }
  if [ "$base_root" = "$wt_root" ]; then
    echo "ticket: integrate: $wt_root is the base checkout, not a task worktree — refusing" >&2
    exit 2
  fi
  base_branch="$(git -C "$base_root" rev-parse --abbrev-ref HEAD)"
  if [ "$base_branch" = "HEAD" ]; then
    echo "ticket: integrate: the base checkout at $base_root is in a detached HEAD state — refusing (no named base branch)" >&2
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

  # A track / plan worktree (`start` recorded branch.<b>.rolepod-plan): the
  # commits ahead of base are the track's earlier tasks — each named by the
  # plan's log (its sha) or by a "Task N" subject — so a dirty tree on top is
  # the next task, not an ambiguity. One unnamed commit keeps the refusal.
  local track_mode="" track_plan wt_branch c csubj csha logged l ahead_unnamed=""
  wt_branch="$(git -C "$wt_root" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  track_plan="$(git -C "$wt_root" config --get "branch.$wt_branch.rolepod-plan" 2>/dev/null)"
  if [ -n "$track_plan" ]; then
    track_mode="track"
    if [ "$ahead" -gt 0 ] && [ -n "$dirty" ]; then
      logged="$(logged_shas "$track_plan" "" 2>/dev/null)"
      for c in $(git -C "$wt_root" rev-list "$base_branch..HEAD" 2>/dev/null); do
        csubj="$(git -C "$wt_root" log -1 --format=%s "$c")"
        if printf '%s\n' "$csubj" | grep -qiE '(^|[^A-Za-z0-9])task[ -]?[0-9]+'; then continue; fi
        csha=""
        while IFS= read -r l; do
          [ -n "$l" ] && case "$c" in "$l"*) csha=1 ;; esac
        done <<EOF
$logged
EOF
        [ -n "$csha" ] && continue
        ahead_unnamed=1
      done
      [ -z "$ahead_unnamed" ] && ahead=0
    fi
  fi
  if [ "$ahead" -gt 0 ] && [ -n "$dirty" ]; then
    echo "ticket: integrate: ambiguous — $ahead commit(s) ahead of $base_branch AND a dirty tree; resolve by hand first" >&2
    exit 1
  fi

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
  stage_out="$(stage_no_docs "$wt_root" 2>&1)"
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

  # This task's reviewer reports: the base checkout's evidence root (the Lead's own
  # convention) and the worktree's own (an owner working inside it per its Bounds),
  # deduped by basename, capped at 10 so this block cannot blow the <=40-line budget.
  local plan_abs task_n f b v seen rp_slug
  plan_abs="$(brief_plan_path "$brief")"
  task_n="$(brief_task_n "$brief")"
  rp_slug=""; [ -z "$plan_abs" ] || rp_slug="$(plan_slug_of "$plan_abs")"
  seen=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    b="$(basename "$f")"
    case " $seen " in *" $b "*) continue ;; esac
    seen="$seen $b"
    v="$(grep -m1 '^VERDICT:' "$f" 2>/dev/null)"
    [ -n "$v" ] && printf '%s: %s\n' "$b" "$v"
  done <<EOF | head -n 10
$(task_review_reports "$base_root/.rolepod/evidence/review" "$rp_slug" "${task_n:-0}" "$wt_root/.git"
  [ "$wt_root/.rolepod/evidence/review" = "$base_root/.rolepod/evidence/review" ] \
    || task_review_reports "$wt_root/.rolepod/evidence/review" "$rp_slug" "${task_n:-0}" "$wt_root/.git")
EOF
  if [ -n "$plan_abs" ] && [ -n "$task_n" ]; then
    printf '%s\n' "$(ship_chain_tail "$wt_root" "$plan_abs" "$task_n" "$base_root" "$track_mode")"
  else
    printf 'git -C "%s" commit -m "<subject>"\n' "$wt_root"
  fi
}

# ── finish ───────────────────────────────────────────────────────────────

cmd_finish() {
  local wt="${1:-}"
  if [ -z "$wt" ] || [ ! -d "$wt" ]; then usage >&2; exit 2; fi

  local wt_root base_root branch base_branch
  wt_root="$(cd "$wt" && pwd)"
  base_root="$(base_root_of "$wt_root")"
  [ -n "$base_root" ] || { echo "ticket: finish: cannot resolve the base checkout for $wt_root" >&2; exit 2; }
  if [ "$base_root" = "$wt_root" ]; then
    echo "ticket: finish: $wt_root is the base checkout, not a task worktree" >&2
    exit 2
  fi

  # docs/rolepod is rescued below, never dirt; a failed status is not "clean".
  local dirt
  dirt="$(git -C "$wt_root" status --porcelain -- . ':(exclude)docs/rolepod' 2>&1)" \
    || { echo "ticket: finish: git status failed in $wt_root: $dirt" >&2; exit 1; }
  if [ -n "$dirt" ]; then
    echo "ticket: finish: worktree is dirty — commit or discard first: $wt_root" >&2
    exit 1
  fi

  branch="$(git -C "$wt_root" rev-parse --abbrev-ref HEAD)"
  base_branch="$(git -C "$base_root" rev-parse --abbrev-ref HEAD)"
  if [ "$base_branch" = "HEAD" ]; then
    echo "ticket: finish: the base checkout at $base_root is in a detached HEAD state — refusing (no named base branch)" >&2
    exit 1
  fi

  if ! git -C "$wt_root" merge-base --is-ancestor "$base_branch" HEAD 2>/dev/null; then
    echo "ticket: finish: $branch is not an ancestor-or-equal of $base_branch's committed state — nothing to merge (integrate + commit first). Base moved? Fix: git -C $wt_root merge $base_branch, re-run the commit check in $wt_root, then finish again" >&2
    exit 1
  fi

  local merge_out merge_rc track_plan
  track_plan="$(git -C "$wt_root" config --get "branch.$branch.rolepod-plan" 2>/dev/null)"
  merge_out="$(git -C "$base_root" merge --ff-only "$branch" 2>&1)"
  merge_rc=$?
  if [ "$merge_rc" -ne 0 ]; then
    echo "ticket: finish: fast-forward merge failed:" >&2
    printf '%s\n' "$merge_out" | tail -n 15 >&2
    exit "$merge_rc"
  fi

  # An unfilled skeleton receipt `start` wrote at base is replaced by the owner's filled one;
  # every other docs/rolepod file is saved by docs-mode.sh rescue below.
  if [ -d "$wt_root/docs/rolepod/tasks" ]; then
    local receipt dest rel
    while IFS= read -r receipt; do
      [ -n "$receipt" ] || continue
      rel="${receipt#"$wt_root/"}"
      dest="$base_root/$rel"
      if [ -e "$dest" ] && grep -qxF 'COMPLETED | PARTIAL | BLOCKED' "$dest" 2>/dev/null; then
        cp "$receipt" "$dest" || { echo "ticket: finish: cannot preserve receipt at $dest" >&2; exit 1; }
      fi
    done <<EOF
$(find "$wt_root/docs/rolepod/tasks" -type f -name 'task-*.md' -print 2>/dev/null)
EOF
  fi

  # Everything under docs/rolepod survives cleanup: rescue copies it to base, never overwriting
  # (a differing file is kept as <name>.from-<branch>). Only rescue exit 0 allows --force.
  local force_flag="" rescue_rc
  if [ -n "$DOCS_MODE" ]; then
    bash "$DOCS_MODE" rescue "$wt_root"; rescue_rc=$?
    if [ "$rescue_rc" -ne 0 ]; then
      echo "ticket: finish: docs rescue failed (exit $rescue_rc) for $wt_root (the merge into $base_branch already landed); worktree kept" >&2
      echo "ticket: finish: never --force; show \`git -C $wt_root status --porcelain -uall\`, then ask the user: commit, move or delete what it lists" >&2
      exit 1
    fi
    force_flag="--force"
  fi

  # Reviewer reports written only inside the worktree survive its removal:
  # the .md files are copied to base, never overwriting an existing report.
  if [ -d "$wt_root/.rolepod/evidence/review" ]; then
    local rep
    mkdir -p "$base_root/.rolepod/evidence/review" 2>/dev/null
    for rep in "$wt_root/.rolepod/evidence/review/"*.md; do
      [ -f "$rep" ] || continue
      cp -n "$rep" "$base_root/.rolepod/evidence/review/" 2>/dev/null || true
    done
  fi

  local rm_out
  if ! rm_out="$(git -C "$base_root" worktree remove $force_flag "$wt_root" 2>&1)"; then
    echo "ticket: finish: worktree remove failed for $wt_root (the merge into $base_branch already landed):" >&2
    printf '%s\n' "$rm_out" | tail -n 15 >&2
    if [ -n "$force_flag" ]; then
      echo "ticket: finish: remove failed even with --force; show \`git -C $wt_root status --porcelain -uall\` and \`git -C $base_root worktree list\`, then ask the user" >&2
    else
      echo "ticket: finish: never --force; show \`git -C $wt_root status --porcelain -uall\`, then ask the user: commit, move or delete what it lists" >&2
    fi
    exit 1
  fi
  git -C "$base_root" worktree prune >/dev/null 2>&1 || true
  git -C "$base_root" branch -d "$branch" >/dev/null 2>&1 \
    || echo "ticket: finish: branch $branch left in place (delete by hand)" >&2

  local agent
  agent="$(find_owner_agent "$base_root" "$wt_root")"
  echo "close: ${agent:-(unrecorded)}"

  # A merged track may unblock a fan-in task (it waits for every track it
  # names to merge) — name it now, `log` cannot see the merge yet.
  if [ -n "$track_plan" ] && [ -f "$track_plan" ]; then
    local frows fid fowner flist=""
    frows="$(ready_now_after "$track_plan" "" "$base_root")"
    if [ -n "$frows" ]; then
      while IFS="$ROW_FS" read -r fid fowner; do
        [ -n "$fid" ] || continue
        if [ -n "$flist" ]; then flist="$flist, Task $fid ($fowner)"; else flist="Task $fid ($fowner)"; fi
      done <<EOF
$frows
EOF
      echo "ready now: $flist"
    fi
  fi
}

# ── log ──────────────────────────────────────────────────────────────────

cmd_log() {
  local plan="${1:-}"; shift || true
  local n="${1:-}"; shift || true
  local sha="" note="" start=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --sha) need_val log --sha $#; sha="$2"; shift 2 ;;
      --note) need_val log --note $#; note="$2"; shift 2 ;;
      --start) start=1; shift ;;
      *) echo "ticket: log: unknown arg: $1" >&2; exit 2 ;;
    esac
  done
  if [ -n "$start" ]; then
    if [ -z "$plan" ] || [ ! -f "$plan" ] || [ -z "$n" ] || [ -n "$sha" ] || [ -n "$note" ]; then
      usage >&2; exit 2
    fi
    if ! plan_task_rows "$plan" | awk -F "$ROW_FS" -v want="$n" '($1 "") == (want "") { f = 1 } END { exit !f }'; then
      echo "ticket: log: no Task $n in $plan — refusing (fail-closed)" >&2
      exit 1
    fi
    if plan_task_rows "$plan" | awk -F "$ROW_FS" -v want="$n" '($1 "") == (want "") && $4 == "1" { f = 1 } END { exit !f }'; then
      echo "ticket: log: Task $n already done in $plan"
      return 0
    fi
    if ! status_write "$plan" "$(status_body "$plan" "$n")"; then
      echo "ticket: log: could not write ## Status in $plan — Task $n not marked running" >&2
      exit 1
    fi
    echo "ticket: log: Task $n running in $plan"
    return 0
  fi
  if [ -z "$plan" ] || [ ! -f "$plan" ] || [ -z "$n" ] || [ -z "$sha" ] || [ -z "$note" ]; then
    usage >&2; exit 2
  fi

  local nl=$'\n'
  if [ "${#note}" -gt 300 ] || [ "${note#*"$nl"}" != "$note" ]; then
    echo "ticket: log: --note must be one line of at most 300 chars (got ${#note} chars). Fix: keep the detail in the task file and pass a one-line summary here" >&2
    exit 2
  fi

  if ! awk "$FENCE_FN"'
    { if (fenceline($0)) next }
    /^## Changes during build/ { found = 1; exit }
    END { exit !found }
  ' "$plan"; then
    echo "ticket: log: no '## Changes during build' heading in $plan — refusing (fail-closed)" >&2
    exit 1
  fi

  if ! plan_task_rows "$plan" | awk -F "$ROW_FS" -v want="$n" '($1 "") == (want "") { f = 1 } END { exit !f }'; then
    echo "ticket: log: no Task $n in $plan — refusing (fail-closed)" >&2
    exit 1
  fi

  local tmp rc bullet
  tmp="$(mktemp "${TMPDIR:-/tmp}/rolepod-ticket-log.XXXXXX")"
  [ -n "$tmp" ] || { echo "ticket: log: mktemp failed" >&2; exit 1; }

  awk -v want="$n" "$FENCE_FN"'
    { if (fenceline($0)) { print; next } }
    /^### / {
      if ($0 ~ /^### (Task ?|T)[0-9]+/) {
        id = $0; sub(/^### (Task ?|T)/, "", id); sub(/[^0-9].*$/, "", id)
        intask = (id == want) ? 1 : 0
      }
      print; next
    }
    /^## / { intask = 0; print; next }
    intask && /^[[:space:]]*-[[:space:]]*\[[[:space:]]\]/ { sub(/\[[[:space:]]\]/, "[x]"); print; next }
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
    # security-lens review (2026-09-24, gate-evidence-paths T9): the
    # decision field is untrusted (a stale/forged phase-log row) — this
    # line is a convenience note, not tamper-proof audit evidence, so it
    # is constrained to the three real decisions rather than echoed raw.
    _decision = best.get("decision")
    if _decision not in ("pass", "deny", "soft"):
        _decision = "?"
    print("gate: %s · tests %d · risk %d · reviewers %d (security %d)" % (
        _decision, _int("tests"), _int("risk"),
        _int("reviewers"), _int("strong")))
' "$gate_phase_log" 2>/dev/null)"
        [ -n "$found" ] && gate_str="$found"
      fi
    fi
  fi
  local task_rel
  task_rel="$(task_file_rel "$plan" "$n")"
  note="$note $gate_str -> $task_rel"

  # Idempotent: the exact same bullet is never appended twice — but only a
  # look-alike line INSIDE "## Changes during build" counts; a Test /
  # evidence sentence elsewhere in the plan quoting the same words is prose,
  # not a prior log entry.
  bullet="- Task $n (\`$sha\`): $note"
  local existing_section
  existing_section="$(awk "$FENCE_FN"'
    { if (fenceline($0)) next }
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
    TICKET_LOG_NOTE="$note" awk -v n="$n" -v sha="$sha" "$FENCE_FN"'
      { if (fenceline($0)) { print; next } }
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
  status_write "$plan" "$(status_body "$plan" "")"
  echo "ticket: log: Task $n updated in $plan"

  # Reviews: a report is named <plan-slug>-task<N>-<lens>.md (the brief's
  # Bounds), so none is copied — pointers to this task's .md reports go under
  # ## Reviews; only a legacy name without that prefix falls back to "written
  # since this task's brief" (never .diff / .log).
  local tfile rdir hfile rf rline rtmp
  tfile="$gate_repo_root/$task_rel"
  rdir="$gate_repo_root/.rolepod/evidence/review"
  hfile="$gate_repo_root/docs/rolepod/handoffs/$(plan_slug_of "$plan")-t${n}-owner.md"
  if [ -n "$gate_repo_root" ] && [ -f "$tfile" ] && [ -f "$hfile" ] && [ -d "$rdir" ]; then
    while IFS= read -r rf; do
      [ -n "$rf" ] || continue
      rline="- .rolepod/evidence/review/$(basename "$rf")"
      grep -qxF -- "$rline" "$tfile" && continue
      rtmp="$(mktemp "${TMPDIR:-/tmp}/rolepod-ticket-task.XXXXXX")" || continue
      if TICKET_RLINE="$rline" awk '{ print } /^## Reviews[[:space:]]*$/ { print ENVIRON["TICKET_RLINE"] }' "$tfile" > "$rtmp" && [ -s "$rtmp" ]; then
        cp "$rtmp" "$tfile"
      fi
      rm -f "$rtmp"
    done <<EOF
$(task_review_reports "$rdir" "$(plan_slug_of "$plan")" "$n" "$hfile")
EOF
  fi

  local ready_rows id2 owner2 list="" log_root lex lx
  log_root="$(git -C "$(dirname "$plan")" rev-parse --show-toplevel 2>/dev/null)"
  ready_rows="$(ready_now_after "$plan" "$n" "$log_root")"
  if [ -n "$ready_rows" ]; then
    while IFS="$ROW_FS" read -r id2 owner2; do
      [ -n "$id2" ] || continue
      if [ -n "$list" ]; then list="$list, Task $id2 ($owner2)"; else list="Task $id2 ($owner2)"; fi
    done <<EOF
$ready_rows
EOF
    echo "ready now: $list"
  fi

  # Every task done in a repo that tracks docs: name the one docs commit.
  if [ -n "$DOCS_MODE" ] && [ -n "$log_root" ] \
    && ! plan_task_rows "$plan" | awk -F "$ROW_FS" 'NF && $4 != "1" { f = 1 } END { exit !f }' \
    && [ "$(bash "$DOCS_MODE" -C "$log_root" status 2>/dev/null)" = "tracked" ]; then
    echo "phase end: git add -- docs/rolepod && git commit -m 'docs: $(basename "$plan")' -- docs/rolepod"
  fi

  # Track end (spec worktree-track-2026-09-30, implement-plan Review): when
  # the last task of a track just logged is done, name the track's range and
  # write its diff, once per track. A plan with `## Tracks` uses the listed
  # tracks; without them a Parallel plan makes each task its own track (id =
  # the task number) and a Sequential plan is one track named `plan`. Idempotent
  # (a re-run reprints the same line), like "ready now:" above. A track with no
  # role-owned task prints nothing: there is nothing for the Lead to review
  # that it did not already build.
  local rrows
  rrows="$(plan_task_rows "$plan")"
  local plan_abs_log feat_log plan_mode_log="" tracked_log="" seq_log="" ttable="" mytrack=""
  plan_abs_log="$(cd "$(dirname "$plan")" && pwd)/$(basename "$plan")"
  feat_log="$(plan_feature_of "$plan_abs_log")"
  if plan_has_tracks "$plan_abs_log"; then
    tracked_log=1
    ttable="$(plan_task_tracks "$plan_abs_log")"
    mytrack="$(track_of "$ttable" "$n")"
  elif [ -n "$log_root" ] && [ "$(git -C "$log_root" config --get "branch.$feat_log/plan.rolepod-plan" 2>/dev/null)" = "$plan_abs_log" ]; then
    plan_mode_log=1; mytrack="plan"
  elif plan_is_sequential "$plan_abs_log"; then
    seq_log=1; mytrack="plan"
  else
    mytrack="$n"
  fi
  if [ -n "$mytrack" ]; then
    local tt_total=0 tt_done=0 tt_role=0 ttid ttowner ttblocked ttdone ttrack tt_ids=" " tt_tip=1 tt_sha2
    while IFS="$ROW_FS" read -r ttid ttowner ttblocked ttdone; do
      [ -n "$ttid" ] || continue
      if [ -n "$tracked_log" ]; then ttrack="$(track_of "$ttable" "$ttid")"
      elif [ -n "$plan_mode_log" ] || [ -n "$seq_log" ]; then ttrack="plan"
      else ttrack="$ttid"; fi
      [ "$ttrack" = "$mytrack" ] || continue
      tt_total=$((tt_total + 1))
      tt_ids="$tt_ids$ttid "
      [ "$ttdone" = "1" ] && tt_done=$((tt_done + 1))
      is_lead_owner "$ttowner" || tt_role=$((tt_role + 1))
    done <<EOF
$rrows
EOF
    # Only the task that closes the track speaks: re-logging an EARLIER task
    # of a finished track (its sha is older) would print a shorter range and
    # overwrite the lens diff with it. This log is NOT the closing one only when
    # another task's logged commit is a strict descendant of $sha — a rebased or
    # amended track (shas no longer ancestors) still prints its line.
    if [ -n "$log_root" ] && git -C "$log_root" rev-parse --verify --quiet "$sha^{commit}" >/dev/null 2>&1; then
      for ttid in $tt_ids; do
        [ "$ttid" = "$n" ] && continue
        tt_sha2="$(task_logged_sha "$plan" "$ttid")"
        [ -n "$tt_sha2" ] || continue
        git -C "$log_root" rev-parse --verify --quiet "$tt_sha2^{commit}" >/dev/null 2>&1 || continue
        [ "$(git -C "$log_root" rev-parse "$tt_sha2^{commit}")" = "$(git -C "$log_root" rev-parse "$sha^{commit}")" ] && continue
        git -C "$log_root" merge-base --is-ancestor "$sha" "$tt_sha2" 2>/dev/null && tt_tip=0
      done
    fi
    if [ "$tt_total" -gt 0 ] && [ "$tt_total" -eq "$tt_done" ] && [ "$tt_role" -gt 0 ] && [ "$tt_tip" -eq 1 ]; then
      local tbase tline tdir tpath first_sha="" tt_code=0 tt_top=R3 ctid cowner cblocked cdone ctier ctrack
      # A docs-only track (every role-owned task briefed R1) or a track with
      # one code task (its owner ran the lenses) takes no track-end review:
      # print just `track <id> done`.
      while IFS="$ROW_FS" read -r ctid cowner cblocked cdone; do
        [ -n "$ctid" ] || continue
        if [ -n "$tracked_log" ]; then ctrack="$(track_of "$ttable" "$ctid")"
        elif [ -n "$plan_mode_log" ] || [ -n "$seq_log" ]; then ctrack="plan"
        else ctrack="$ctid"; fi
        [ "$ctrack" = "$mytrack" ] || continue
        is_lead_owner "$cowner" && continue
        ctier="$(ROLEPOD_BRIEF_NOREC=1 bash "$LINT" --brief "$ctid" "$plan_abs_log" --main 2>/dev/null | awk '/^## Tier/ { getline; print substr($0, 1, 2); exit }')"
        [ "$ctier" = "R1" ] || tt_code=$((tt_code + 1))
        case "$ctier" in R4) tt_top=R4 ;; R3) [ "$tt_top" = "R4" ] || tt_top=R3 ;; esac
      done <<EOF
$rrows
EOF
      if [ "$tt_code" -le 1 ]; then
        printf 'track %s done\n' "$mytrack"
        return 0
      fi
      if [ -n "$tracked_log" ] || [ -n "$plan_mode_log" ]; then
        # Outside a git repo there is no base to name: stay silent.
        tbase=""
        if [ -n "$log_root" ]; then
          tbase="$(git -C "$log_root" rev-parse --abbrev-ref HEAD 2>/dev/null)"
          [ -n "$tbase" ] || tbase="HEAD"
        fi
      else
        # No track worktree: the commits already sit on the base checkout, so
        # the range starts at the parent of the track's first logged commit
        # (a per-task track: this task's own). Anchored to the exact bullet
        # shape this function writes above ("- Task N (`<sha>`): <note>").
        if [ -n "$seq_log" ]; then
          first_sha="$(logged_shas "$plan" "" | head -n 1)"
        else
          first_sha="$sha"
        fi
        tbase=""
        [ -z "$first_sha" ] || tbase="${first_sha}^"
      fi
      if [ -n "$tbase" ]; then
        # three dots: from the merge-base, so a base that moved on (another
        # track merged first) never shows up reversed in the lens diff
        tline="track $mytrack done — review: $tbase...$sha"
        tdir="$log_root/.rolepod/evidence/review"
        tpath="$tdir/${feat_log}-${mytrack}.diff"
        # Outside a git repo the range still prints, just without the path.
        if [ -n "$log_root" ] && git -C "$log_root" rev-parse --verify --quiet "$sha^{commit}" >/dev/null 2>&1 && mkdir -p "$tdir" 2>/dev/null; then
          lex=()
          while IFS= read -r lx; do lex+=("$lx"); done < <(review_excludes "$log_root")
          if {
            git -C "$log_root" diff --stat "$tbase...$sha" -- . "${lex[@]}"
            git -C "$log_root" diff -U10 "$tbase...$sha" -- . "${lex[@]}"
          } > "$tpath" 2>/dev/null; then
            tline="$tline; lens diff: $tpath"
          fi
        fi
        printf '%s\n' "$tline"
        # The cell lives in plan-lint.sh --review-set (one home); a failing
        # call prints a pointer line and never fails log.
        ROLEPOD_BRIEF_NOREC=1 bash "$LINT" --review-set --tier "$tt_top" 2>/dev/null \
          || echo "Review: unknown — run plan-lint.sh --review-set --tier $tt_top"
        echo "Track end: a track with two or more code tasks → its last code task's owner runs \`convening-code-review\` with the \`Review:\` line \`ticket.sh log\` prints, on the track diff, and fixes each BLOCKER / MAJOR (owner gone → a fresh owner of its role; an owner that cannot dispatch returns the diff unreviewed and the Lead runs \`convening-code-review\`); the Lead commits the fixes in the track worktree, then \`ticket.sh finish <worktree>\` merges the track. A track with one code task → its owner ordered its own review before returning, and the track takes no track-end review."
      fi
    fi
  fi
}

# ── status ───────────────────────────────────────────────────────────────

cmd_status() {
  local plan="${1:-}"
  if [ -z "$plan" ] || [ ! -f "$plan" ] || [ $# -ne 1 ]; then usage >&2; exit 2; fi
  status_body "$plan" ""
}

# ── review-diff (C67) ────────────────────────────────────────────────────
# The one home of the frozen review diff, the H1 / H2 tree and the fix delta
# `convening-code-review` hands its reviewers. Stages the whole tree (`git add -A`, as
# every review round always did, then `git reset -q -- docs/rolepod`, the only reset:
# docs never stage on the whole-tree path) or, with `-- <path>...`, only those
# paths (a named docs/rolepod path stages like any other); never commits,
# stashes or checks out. The exclude list is review_excludes.
RD_USAGE="usage: ticket.sh review-diff start <name> [-- <path>...] | ticket.sh review-diff delta <name> <H1-tree> <k: 2|3|4> [-- <path>...]"

cmd_review_diff() {
  local sub="${1:-}" name="${2:-}" h1="" k="" top dir out h2 want p
  local paths=() live=() stage=() stageu=() ex=() spec=()
  case "$sub" in
    start) if [ $# -eq 2 ]; then :
           elif [ $# -ge 4 ] && [ "$3" = "--" ]; then paths=("${@:4}")
           else echo "ticket: review-diff: $RD_USAGE" >&2; exit 2; fi ;;
    delta) if [ $# -eq 4 ]; then :
           elif [ $# -ge 6 ] && [ "$5" = "--" ]; then paths=("${@:6}")
           else echo "ticket: review-diff: $RD_USAGE" >&2; exit 2; fi
           h1="$3"; k="$4" ;;
    *) echo "ticket: review-diff: $RD_USAGE" >&2; exit 2 ;;
  esac
  case "$name" in
    ""|*[!A-Za-z0-9._-]*) echo "ticket: review-diff: name must match [A-Za-z0-9._-]+ — $RD_USAGE" >&2; exit 2 ;;
  esac
  if [ "$sub" = "delta" ]; then
    case "$k" in
      2|3|4) ;;
      *) echo "ticket: review-diff: k must be 2, 3 or 4 — $RD_USAGE" >&2; exit 2 ;;
    esac
    if [ "$(git cat-file -t "$h1" 2>/dev/null)" != "tree" ]; then
      echo "ticket: review-diff: not a tree object: $h1" >&2
      exit 2
    fi
  fi
  top="$(git rev-parse --show-toplevel 2>/dev/null)" \
    || { echo "ticket: review-diff: not in a git checkout" >&2; exit 2; }
  if [ "${#paths[@]}" -gt 0 ]; then
    # Only a path that exists (worktree, index or HEAD — a path the task
    # deleted counts) is staged; never fall back to the whole tree.
    for p in "${paths[@]}"; do
      # A path is literal and relative to the checkout root: pathspec magic,
      # ".", "..", an absolute path or "" would widen the stage to the tree.
      # (a path made only of dots and slashes is the tree root or its parent)
      case "$p" in
        ""|:*|../*|*/..|*/../*|/*) echo "ticket: review-diff: path must be a plain checkout-relative path, not '$p' — $RD_USAGE" >&2; exit 2 ;;
      esac
      case "${p//[.\/]/}" in
        "") echo "ticket: review-diff: path must be a plain checkout-relative path, not '$p' — $RD_USAGE" >&2; exit 2 ;;
      esac
      if [ -n "$(git --literal-pathspecs -C "$top" ls-files -- "$p" 2>/dev/null)" ]; then
        live+=("$p")
        stageu+=("$p")   # tracked: staged below, `add -A` first, `add -u` when ignored files refuse it
      elif git -C "$top" check-ignore -q -- "$p" 2>/dev/null; then
        # nothing tracked and gitignored: `git add` would refuse it and fail the call
        echo "ticket: review-diff: skipped path (gitignored): $p" >&2
      elif [ -e "$top/$p" ]; then
        live+=("$p"); stage+=("$p")
      elif [ -n "$(git --literal-pathspecs -C "$top" ls-tree -r --name-only HEAD -- "$p" 2>/dev/null)" ]; then
        live+=("$p")   # deleted and already staged: diffed, nothing left to add
      else
        echo "ticket: review-diff: skipped path (not in worktree, index or HEAD): $p" >&2
      fi
    done
    [ "${#live[@]}" -gt 0 ] || { echo "ticket: review-diff: none of the paths exists or is reviewable (missing or gitignored) — $RD_USAGE" >&2; exit 2; }
    if [ "${#stage[@]}" -gt 0 ]; then
      git --literal-pathspecs -C "$top" add -A -- "${stage[@]}" || { echo "ticket: review-diff: git add -A failed" >&2; exit 1; }
    fi
    for p in ${stageu[@]+"${stageu[@]}"}; do
      # git add -A refuses a dir holding ignored files even when tracked ones sit in it
      git --literal-pathspecs -C "$top" add -A -- "$p" 2>/dev/null \
        || git --literal-pathspecs -C "$top" add -u -- "$p" \
        || { echo "ticket: review-diff: git add failed for $p" >&2; exit 1; }
    done
    spec=("${live[@]}")
  else
    stage_no_docs "$top" || { echo "ticket: review-diff: git add -A failed" >&2; exit 1; }
    spec=(.)
  fi
  while IFS= read -r want; do ex+=("$want"); done < <(review_excludes "$top")
  dir="$top/.rolepod/evidence/review"
  if [ "$sub" = "start" ]; then
    out="$dir/$name.diff"
    if git -C "$top" diff --cached --quiet -- "${spec[@]}" "${ex[@]}"; then
      echo "ticket: review-diff: empty diff" >&2
      exit 1
    fi
    mkdir -p "$dir" || { echo "ticket: review-diff: cannot create $dir" >&2; exit 1; }
    {
      git -C "$top" diff --cached --stat -- "${spec[@]}" "${ex[@]}"
      git -C "$top" diff --cached -U10 -- "${spec[@]}" "${ex[@]}"
    } > "$out" || { echo "ticket: review-diff: cannot write $out" >&2; rm -f "$out"; exit 1; }
    h2="$(git -C "$top" write-tree)" || { echo "ticket: review-diff: git write-tree failed" >&2; rm -f "$out"; exit 1; }
    echo "diff: $out"
    echo "H1: $h2"
    [ "${#paths[@]}" -gt 0 ] || echo "limitation: whole-tree diff — no path list, so other work in this checkout is included"
  else
    out="$dir/$name-r$k.diff"
    h2="$(git -C "$top" write-tree)" || { echo "ticket: review-diff: git write-tree failed" >&2; exit 1; }
    if git -C "$top" diff --quiet "$h1" "$h2" -- "${spec[@]}" "${ex[@]}"; then
      echo "ticket: review-diff: empty diff" >&2
      exit 1
    fi
    mkdir -p "$dir" || { echo "ticket: review-diff: cannot create $dir" >&2; exit 1; }
    git -C "$top" diff "$h1" "$h2" -U10 -- "${spec[@]}" "${ex[@]}" > "$out" \
      || { echo "ticket: review-diff: cannot write $out" >&2; rm -f "$out"; exit 1; }
    echo "diff: $out"
    echo "H2: $h2"
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
  status) cmd_status "$@" ;;
  review-diff) cmd_review_diff "$@" ;;
  *) echo "ticket: unknown subcommand: $SUB" >&2; usage >&2; exit 2 ;;
esac
