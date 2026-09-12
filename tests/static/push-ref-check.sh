#!/usr/bin/env bash
# Static test — the push-ref-check hook.
#
# It shows what a push would publish and never denies. The property that
# matters: silence on the common case (your own single commit) and a line
# naming every commit when the ref carries more than you made. Exercised
# against a real throwaway repo, not a mocked git.
#
# Run directly: bash tests/static/push-ref-check.sh
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="$REPO_DIR/hooks/push-ref-check.sh"

fail=0
pass() { echo "  ✓ $1"; }
bad()  { echo "  ✗ $1"; fail=$((fail + 1)); }

echo "push-ref-check:"

[ -x "$HOOK" ] && pass "hook exists and is executable" || bad "hook missing or not executable"

# Build a throwaway origin + clone so `@{push}` is real.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
(
  set -e
  git init -q --bare "$TMP/origin.git"
  git clone -q "$TMP/origin.git" "$TMP/work"
  cd "$TMP/work"
  git config user.email t@e.st; git config user.name test
  git commit -q --allow-empty -m "base"
  git branch -M main
  git push -q origin main
  git config push.default current
  git remote set-head origin -a     # a real clone has this symref; a bare one may not
) >/dev/null 2>&1 || { bad "could not build the fixture repo"; echo "  fixture failed"; exit 1; }

run_hook() { # $1 = cwd, $2 = command string
  printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(python3 -I -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$2")" \
    | (cd "$1" && bash "$HOOK" 2>/dev/null)
}

ctx() { python3 -I -c '
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    sys.exit(0)
print(json.loads(raw)["hookSpecificOutput"]["additionalContext"])
' 2>/dev/null; }

# 1. Nothing to publish → silent.
OUT=$(run_hook "$TMP/work" "git push")
[ -z "$OUT" ] && pass "ref already published → silent" || bad "expected silence, got: ${OUT:0:80}"

# 2. One commit ahead → silent. Pushing what you just made needs no line.
(cd "$TMP/work" && git commit -q --allow-empty -m "mine one") >/dev/null 2>&1
OUT=$(run_hook "$TMP/work" "git push")
[ -z "$OUT" ] && pass "one commit ahead → silent (the common case)" || bad "one commit should be silent, got: ${OUT:0:80}"

# 3. Two ahead → names both. This is the incident shape: a commit you did not
#    make is already on the ref when you push your own.
(cd "$TMP/work" && git commit -q --allow-empty -m "someone elses") >/dev/null 2>&1
OUT=$(run_hook "$TMP/work" "git push" | ctx)
if printf '%s' "$OUT" | grep -q 'publishes 2 commits' \
   && printf '%s' "$OUT" | grep -q 'mine one' \
   && printf '%s' "$OUT" | grep -q 'someone elses'; then
  pass "two commits ahead → names every commit on the ref"
else
  bad "expected both commits named, got: ${OUT:0:120}"
fi

# 4. The message stays inside the lean-message budget.
LEN=$(printf '%s' "$OUT" | wc -c | tr -d ' ')
[ "$LEN" -le 600 ] && pass "message ${LEN}B within the 600B hook budget" || bad "message ${LEN}B over budget"

# 5. A branch with no upstream still works — that is the shape the
#    branch-per-worktree rule creates, and where `@{push}` fatals.
(cd "$TMP/work" && git checkout -q -b solo && git commit -q --allow-empty -m "on solo") >/dev/null 2>&1
OUT=$(run_hook "$TMP/work" "git push" | ctx)
if printf '%s' "$OUT" | grep -q 'publishes'; then
  pass "branch with no upstream → falls back, still reports"
else
  bad "no-upstream branch produced nothing: ${OUT:0:100}"
fi

# 6. Only a real `git push` triggers it.
quiet_ok=1
for cmd in "git status" "git commit -m push" "echo git push" "git pushd" "git push --dry-run" "git push -n" "git push --help"; do
  OUT=$(run_hook "$TMP/work" "$cmd")
  [ -z "$OUT" ] || { bad "non-publishing command fired the hook: $cmd"; quiet_ok=0; }
done
[ "$quiet_ok" -eq 1 ] && pass "non-publishing commands stay silent (status, commit -m push, echo, pushd, --dry-run, -n, --help)"

# 7. A push reached through a compound command still counts. No explicit
#    refspec here — this check is about finding the push, not about the range
#    (a refspec naming a destination that does not exist yet is silent by
#    design, which is 7d).
OUT=$(run_hook "$TMP/work" "cd . && git push" | ctx)
printf '%s' "$OUT" | grep -q 'publishes' \
  && pass "compound command (cd && git push) is detected" \
  || bad "compound git push was missed"

# 7b. Real pushes reached through a prefix or a git option. Each of these was
#     a silent miss before review: the option value was read as the
#     subcommand, or the prefix token was not command position.
for cmd in "git -C . push" "sudo git push" "GIT_SSH=x git push" "bash -c \"git push\""; do
  OUT=$(run_hook "$TMP/work" "$cmd" | ctx)
  printf '%s' "$OUT" | grep -q 'publishes' \
    && pass "detected: $cmd" \
    || bad "missed a real push: $cmd"
done

# 7c. An explicit `src:dst` refspec publishes to dst, which need not be this
#     branch. Measuring against the branch's own upstream reported the wrong
#     count and, under the 2-commit threshold, reported nothing at all.
#     The fixture makes the two answers DIFFER on purpose: main is 2 ahead of
#     origin/main but 3 ahead of origin/release, so a hook that measured the
#     branch's own upstream would say 2. Asserting the exact count is what
#     makes this test fail when the destination logic is removed — asserting
#     only that it "reports something" passed either way.
(
  set -e
  cd "$TMP/work"
  git checkout -q main
  git push -q origin main            # main and origin/main level
  git checkout -q -b release
  git commit -q --allow-empty -m "release only one"
  git commit -q --allow-empty -m "release only two"
  git push -q origin release
  git checkout -q main
  git commit -q --allow-empty -m "one of mine"
  git push -q origin main            # origin/main advances, origin/release does not
  git commit -q --allow-empty -m "two of mine"
  git commit -q --allow-empty -m "three of mine"
) >/dev/null 2>&1
OUT=$(run_hook "$TMP/work" "git push origin HEAD:release" | ctx)
if printf '%s' "$OUT" | grep -q 'publishes 3 commits'; then
  pass "explicit src:dst refspec counted against the destination (3), not the branch (2)"
else
  bad "refspec range came from the wrong ref — expected 'publishes 3 commits', got: ${OUT:0:110}"
fi

# 7d. A destination branch that does not exist yet carries nobody else's work.
OUT=$(run_hook "$TMP/work" "git push origin HEAD:brand-new")
[ -z "$OUT" ] && pass "new destination branch → silent (nothing there to warn about)" \
  || bad "new destination should be silent, got: ${OUT:0:80}"

# 7e. Source ref comes from the refspec, not from HEAD. Pushing a branch you
#     are NOT checked out on is the incident shape with one more twist: the
#     range must measure that branch, or the hook describes something else
#     entirely and stays silent on a real publish.
(
  set -e
  cd "$TMP/work"
  git checkout -q -b feature
  git commit -q --allow-empty -m "unrelated feature work"
) >/dev/null 2>&1
OUT=$(run_hook "$TMP/work" "git push origin main:main" | ctx)
if printf '%s' "$OUT" | grep -q 'publishes 2 commits' \
   && printf '%s' "$OUT" | grep -q 'three of mine' \
   && ! printf '%s' "$OUT" | grep -q 'unrelated feature work'; then
  pass "source ref taken from the refspec, not HEAD (main's 2, not feature's)"
else
  bad "range came from HEAD instead of the named source: ${OUT:0:120}"
fi

# 7f. A force refspec is still that refspec — the `+` must not leak into the
#     ref name, or the lookup misses and the hook goes quiet on a force push.
OUT=$(run_hook "$TMP/work" "git push origin +main:main" | ctx)
printf '%s' "$OUT" | grep -q 'publishes 2 commits' \
  && pass "force refspec (+src:dst) resolves the same as src:dst" \
  || bad "force refspec lost its destination: ${OUT:0:100}"

# 7g. A bare `git push origin <branch>` names the source too.
OUT=$(run_hook "$TMP/work" "git push origin main" | ctx)
printf '%s' "$OUT" | grep -q 'publishes 2 commits' \
  && pass "bare 'git push origin main' measures main, not HEAD" \
  || bad "bare remote+branch push measured the wrong ref: ${OUT:0:100}"

# 7h. A push that is not the first git command on the line.
OUT=$(run_hook "$TMP/work" "git status && git push origin main" | ctx)
printf '%s' "$OUT" | grep -q 'publishes' \
  && pass "push after another git command on the same line is found" \
  || bad "scanner stopped at the first git and missed the push"

# 7i. A prefix carrying its own flags.
for cmd in "sudo -u root git push origin main" "xargs -I{} git push origin main"; do
  OUT=$(run_hook "$TMP/work" "$cmd" | ctx)
  printf '%s' "$OUT" | grep -q 'publishes' \
    && pass "detected through a flag-carrying prefix: ${cmd%% *}" \
    || bad "missed a push behind a flag-carrying prefix: $cmd"
done

# 7j. Multi-ref pushes cannot be described by one range — silence beats a
#     number that describes a different ref.
multi_ok=1
for cmd in "git push --mirror origin" "git push --all origin" "git push --tags origin"; do
  OUT=$(run_hook "$TMP/work" "$cmd")
  [ -z "$OUT" ] || { bad "multi-ref push reported a single range: $cmd"; multi_ok=0; }
done
[ "$multi_ok" -eq 1 ] && pass "--mirror / --all / --tags stay silent (no single range describes them)"

# 7k. HEAD and @ are revs, not ref names. `git push origin HEAD` writes the
#     branch you are on; resolving `origin/HEAD` instead lands on the remote's
#     default branch and reports ordinary ancestor commits as if they needed
#     clearing — a fabricated warning, worse than silence, on the commonest
#     non-bare push form.
(
  set -e
  cd "$TMP/work"
  git checkout -q -b fresh main
  git commit -q --allow-empty -m "fresh one"
  git commit -q --allow-empty -m "fresh two"
) >/dev/null 2>&1
for ref in HEAD @; do
  OUT=$(run_hook "$TMP/work" "git push origin $ref")
  if [ -z "$OUT" ]; then
    pass "git push origin $ref → silent (destination origin/fresh does not exist)"
  else
    bad "$ref resolved to the wrong destination: $(printf '%s' "$OUT" | ctx | head -c 110)"
  fi
done

# 7l. Once that destination exists, HEAD must measure it — not stay silent.
(cd "$TMP/work" && git push -q origin fresh && git commit -q --allow-empty -m "fresh three" \
  && git commit -q --allow-empty -m "fresh four") >/dev/null 2>&1
OUT=$(run_hook "$TMP/work" "git push origin HEAD" | ctx)
if printf '%s' "$OUT" | grep -q 'publishes 2 commits' \
   && ! printf '%s' "$OUT" | grep -q 'fresh one'; then
  pass "git push origin HEAD measures origin/fresh (2), not the default branch"
else
  bad "HEAD measured the wrong ref: ${OUT:0:120}"
fi

# 8. Outside a git repo → silent, never an error.
OUT=$(run_hook "$TMP" "git push")
[ -z "$OUT" ] && pass "outside a repo → silent, fail-open" || bad "expected silence outside a repo"

# 9. It never denies: no permissionDecision in any output.
OUT=$(run_hook "$TMP/work" "git push")
printf '%s' "$OUT" | grep -q 'permissionDecision' \
  && bad "hook emitted a permission decision — it must only inform" \
  || pass "never denies, only informs"

if [ $fail -eq 0 ]; then echo "  all push-ref-check checks passed"; else exit 1; fi
