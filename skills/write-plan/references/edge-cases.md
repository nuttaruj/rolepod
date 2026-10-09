<!-- Load from write-plan when one of these cases applies. Each section names its trigger. -->

# write-plan edge cases

## Module boundary map (step 7)

A map exists → every new cross-module import or dependency-direction reversal is called out and justified. An undeclared crossing = fix the plan, or update the map with the user.

## No test infrastructure (step 3)

No test infrastructure at all → the FIRST task builds the minimal harness (runner config + one passing smoke test), so every later Command is runnable. Never plan Commands against a runner that does not exist.

## No plan-lint (steps 7-8)

`plan-lint.sh` lives in this skill's `scripts/`. Missing → run the inline check on the saved plan; it exits 0 only when the plan has a Failure policy and every task a Command:

```bash
grep -q '^## Failure policy' <plan> && awk '/^### (Task ?|T)[0-9]/{t++;c[t]=0;i=1;next} /^## /{i=0} i&&/Command:/{c[t]=1} END{if(!t)exit 1;for(k=1;k<=t;k++)if(!c[k])exit 1}' <plan>
```

## Saving the plan (step 8)

- Multi-session → `docs/rolepod/plans/<feature>-YYYY-MM-DD.md`. Re-planning never overwrites: a new dated file, `-v2` only when the date is the same.
- Before the first save: `scripts/docs-mode.sh status` prints `undecided` → run `scripts/docs-mode.sh ignore`, then the commit it prints, and pass its user line on; `track` only on the user's yes. No script → list `docs/rolepod/` in `.gitignore`, committed alone.

## Harness plan mode, team issues, several plans at once (step 8)

- **Harness plan mode** active (a read-only planning state with its own approval gate) → present the plan through that gate and defer every disk write until it approves. Do not fight the block; it is the same boundary as the first guardrail (no edit before the plan).
- **Team issues** (several builders) → `references/team-issues.md`.
- **Several plans at once** (a phase each, for separate sessions) → one agent per plan on the CLI's default agent, no role and no `model`, so each runs on the model the user chose for the Lead; its brief names the spec, the phase, the output file under `docs/rolepod/plans/` and a `plan-lint.sh` run on it; the Lead reads each lint and spot-checks each plan. No default agent → the Lead writes them in turn.
