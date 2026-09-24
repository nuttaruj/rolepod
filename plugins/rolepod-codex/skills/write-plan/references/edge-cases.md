<!-- Load from write-plan when one of these cases applies. Each section names its trigger. -->

# write-plan edge cases

## No module boundary map (step 1)

Work spans 2+ modules and NO map exists → offer a ONE-TIME bootstrap: a scout + `system-architect` derive the module list, dependency direction and no-touch zones from the code into the project's CLAUDE.md for approval — recently-active modules first (`git log`), the whole repo only when small. No subagents → the Lead derives it.

## Module boundary map (step 7)

A map exists → every new cross-module import or dependency-direction reversal is called out and justified. An undeclared crossing = fix the plan, or update the map with the user.

## Prefactor (step 2)

Two edge-free tasks on one file → **prefactor first**: an extract task giving them disjoint files ("make the change easy, then make the easy change"). Or declare Sequential and say why in the Parallel layout line.

## Wide refactor (step 2)

A wide refactor with no safe single-commit path: expand (new path beside the old) → migrate consumers in reviewable green batches → contract (delete the old path once no caller remains).

## Security-surface task (step 2)

A task that guards, gates or restores (a security surface) gets a **threat-model** task first: the written attack list its reviewers verify against (symlinks, case-folded names, forged evidence, moved refs, ignore rules, the kill path…). Reviewers never discover it round by round.

## No test infrastructure (step 3)

No test infrastructure at all → the FIRST task bootstraps the minimal harness (runner config + one passing smoke test), so every later Command is runnable. Never plan Commands against a runner that does not exist.

## No plan-lint (steps 7-8)

`plan-lint.sh` lives in `~/.rolepod/bin/`, the plugin's `scripts/`, or `scripts/` in the source repo. None of them available → run the inline check on the saved plan; it exits 0 only when the plan has a Failure policy and every task a Command:

```bash
grep -q '^## Failure policy' <plan> && awk '/^### (Task ?|T)[0-9]/{t++;c[t]=0;i=1;next} /^## /{i=0} i&&/Command:/{c[t]=1} END{if(!t)exit 1;for(k=1;k<=t;k++)if(!c[k])exit 1}' <plan>
```

## Saving the plan (step 8)

- Multi-session → `docs/rolepod/plans/<feature>-YYYY-MM-DD.md`. Re-planning never overwrites: a new dated file, `-v2` only when the date is the same.
- `docs/rolepod/` is private by default: before the first save run `grep -qx 'docs/rolepod/' .gitignore || echo 'docs/rolepod/' >> .gitignore`; a repo that deliberately tracks its working docs creates `.rolepod/docs-tracked`.

## Harness plan mode (step 8)

Harness plan mode active (a read-only planning state with its own approval gate) → present the plan through that gate and defer every disk write until it approves. Do not fight the block; it is the same boundary as the first guardrail (no edit before the plan).
