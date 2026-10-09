# Red-Green-Revert Cycle

A logic or bug fix whose test file changed after its red run.

A regression test for a bug must follow this cycle. Skip any step → you don't know if the test tests the fix.

```
1. Write the test that captures the bug behavior
2. Run it — must FAIL with the bug present (RED)
3. Apply the fix
4. Run it — must PASS (GREEN)
5. Revert the fix in a throwaway `git worktree` (never a stash: it empties the tree in-flight reviewers read — same rule for any "does it fail on HEAD too?" check of a pre-existing failure)
6. Run it — MUST FAIL AGAIN (proves the test is testing the fix, not something else)
7. Restore the fix
8. Run it — must PASS (final GREEN)
```

If step 6 passes — the test is not actually testing the bug. The assertion is weak, or the test exercises unrelated code, or the bug was never the cause. Tighten the test before claiming the bug is fixed.

## Revert in one call

Steps 5-8 cost three turns when run in place. Run the red proof as ONE
command in a throwaway worktree — the fix in your tree is never touched:

```bash
lab=$(mktemp -d); git worktree add -q --detach "$lab/t" HEAD
git diff --binary HEAD > "$lab/all.patch"; [ -s "$lab/all.patch" ] && git -C "$lab/t" apply "$lab/all.patch"   # uncommitted work, tracked test edits included
git diff --binary HEAD -- . ':(exclude)<test paths>' > "$lab/fix.patch"   # the fix ONLY; fix already committed → diff against the commit before it, production paths only
for p in <untracked test files>; do mkdir -p "$lab/t/$(dirname "$p")"; cp "$p" "$lab/t/$p"; done
git -C "$lab/t" apply -R "$lab/fix.patch"                                  # remove the fix, keep the test
( cd "$lab/t" && <runner> <one named test> ); red=$?                       # expect NON-ZERO exit + the named assertion
git worktree remove -f "$lab/t"; rm -rf "$lab"; test "$red" -ne 0
```

Red means a NON-ZERO exit AND the named assertion in the output (pytest / jest /
go = 1, cargo = 101) — the assertion string, not the code, is what rules out a
collection / import / compile error, a skip, or a 0-test run; those are NOT red —
fix the harness and rerun. Dependencies must resolve inside the worktree (symlink
`node_modules`, point `PYTHONPATH` / Go workspace at the tree; a fresh worktree
has EMPTY submodules and may hold LFS pointers); when they cannot, fall back to
steps 5-8 in place. Review `fix.patch` before applying it in reverse: only the
implementation, no test or fixture hunks — a file holding both the fix and its
test (Rust `#[cfg(test)]`, a doctest, a same-module test) cannot be split by
path: use the three-step revert in place. Final green after the restore confirms
the test is tight and the fix is minimal.
