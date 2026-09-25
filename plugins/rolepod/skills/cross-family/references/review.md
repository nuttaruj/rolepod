<!-- Load for a review kind that needs the member order, --all, the anchor rule or the degradation table. SKILL.md step 3 carries the run itself. -->

# Review kind — order, anchor, degradation

Rolepod's CLIs span model families — Claude, Codex (GPT), Google (served by Antigravity `agy`; the standalone Gemini CLI is retired for individual accounts and is never in the pool), plus the multi-model harnesses Cursor and OpenCode (their model = whatever default their owner configured — recorded, never a criterion).
Any CLI can be the Lead. The review goes to a different CLI than the Lead's, never to the Lead's own.

## Member order

| Family (CLI) | Reviews best |
|-------|--------------|
| OpenAI (`codex`) | depth · security · logic rigor |
| Google (`agy`) | breadth · cross-file · large-diff sweep |
| Anthropic (`claude`) | architecture · code quality · maintainability |
| Cursor / OpenCode | the family of their default model — the runner tells you |

1. Read the diff; name the axes it needs (a diff can need several).
2. The pool file is the order — put the member owning the dominant axis first, so a project can pin it.
3. ONE member — the first usable in pool order — reviews every axis the diff needs. `--all` (every usable member, concurrently, each anchored) only on the user's ask; each CLI is one opinion.
4. Launch every routed reviewer — the runner and internal agents alike — in ONE dispatch. They read the same frozen diff independently; nothing is gained by waiting for one before starting the next.

## What anchors

- Only the runner's anchor counts: the raw file under `.rolepod/evidence/external/` plus its `"reviewer":"external"` phase-log line (cli, family, `model:"default"`, raw path, `brief_sha`, the job id). A hand-typed line or a hand-rolled external call is ignored.
- The Lead still appends its own merged review verdict line.
- The member runs on its own CLI's default model — its owner's cost decision. The model tier policy governs only the Lead's CLI.
- Why the external goes first: each plan is a separate flat-rate quota; the main plan carries implementation, so one-shot cold-context review moves to a satellite plan whenever a usable non-Lead CLI exists. the `rolepod-stats` skill reports external passes vs internal strong dispatches.

## Degradation

| Pool | Review |
|---------------|---------|
| ≥ 2 usable | the first member by dominant axis reviews the whole diff; `--all` only on the user's ask |
| 1 usable | it reviews the whole diff |
| 0 usable (exit 3 / 4) | internal strong reviewer, plus the vertical fallback when one exists; Cross-model line `NOT RUN — <reason from the runner>` |
| off (exit 5 — no file / `none`) | internal strong reviewer is the pass; Cross-model line `NOT RUN — cross-family off (opt-in)`; never enable unasked |

## Jobs and health

- `cross-family.sh --jobs` lists running and finished jobs; `--kill <job-id>` stops one with its process group.
- Installed ≠ usable: exit ≠ 0, a timeout, or too little output (review < 500 bytes, other kinds < 200) → an `external-fail` phase-log line and the next member.
- `cross-family.sh --probe` sends each member a one-line prompt (one call each); `ROLEPOD_DOCTOR_PROBE=1 make doctor` does the same.
