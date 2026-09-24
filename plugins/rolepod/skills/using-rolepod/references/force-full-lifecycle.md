<!-- Load when entering force-full mode. -->
<!-- The router detects the trigger; this file is the force-full detail. -->

# Force-full lifecycle

Triggers — the message opens with one of: `/rolepod-full <task>` ·
`$rolepod-full <task>` (Codex) · `force full lifecycle` ·
`run full rolepod lifecycle` · `rolepod mode: full lifecycle` (exact). The
`rolepod-full` skill is the explicit entrypoint. Bare `/rolepod`,
`rolepod mode`, `run all phases` and `no skip` are not triggers; they
auto-route.

Run **every phase in order, no skips** — even a one-line fix — with external
adversarial reviewers when configured. The user opted out of the
auto-router's skip rules on purpose. They can still override mid-flow
("skip review", "just ship").

## The six phases

1. **Define — `write-spec`** — discovery in frontier rounds, 2-3
   approaches, approval, spec self-review; inline or file per its Contract
   step.
2. **Plan — `write-plan`** — break the approved spec into bite-sized steps
   (2-5 min each). If multi-agent, write the cohesion contract before spawning.
3. **Build — `implement-plan`** — execute task-by-task with bounded scope +
   explicit file ownership. Bug-flavored tasks route through `debug-issue`.
   Every commit passes the commit gates.
4. **Verify — `check-work`** — no completion claim without fresh verification
   evidence in this message.
5. **Review — `review-code`** — one read-only reviewer + risk-appropriate reviewers.
   External adversarial reviewers (`cross-family` — any installed CLI other
   than the Lead's) when configured; otherwise universal-reviewer / security-engineer;
   qa-tester for user-visible (E2E / UI) behaviour.
6. **Ship — `finish-work`** — its Pre-merge gates, required CI lane checks, then
   the 4-option branch finish menu (merge / open PR / keep open / discard).

## Execution backend

Same intent on every CLI; the backend differs by capability. Pick the best
available and announce it.

| Environment | Backend |
|---|---|
| Claude + agent-teams enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, v2.1.32+) | teammate mode — multi-process team |
| Claude without agent-teams, or user asked for single-process | Task / subagent dispatch + cohesion contract |
| Codex | Codex subagents |
| Gemini | Gemini subagents; inline fallback when unsupported |

Teammate mode costs ~4× tokens (one context window per teammate). It is the
default heavy backend for `/rolepod-full` on a teams-enabled Claude —
`/rolepod-full` already signals feature-scale, full ceremony. If the user
wants the lighter single-process path, they say so and the backend drops to
Task / subagents.

## Start banner — announce at the start of force-full mode

```
Routing: Force full lifecycle via /rolepod-full
Phase: Define (entering Phase 0 discovery dialogue)
Execution: <teammate mode | Task/subagents | Codex subagents | Gemini subagents | inline fallback>
Skipping: none (user opted out of router skip rules)
Next step: <first question or context read>
```

## Careful-mode rigor (default-on in force-full mode)

- ≤3 files per commit
- Mandatory peer review even for small diffs (no skip on ≤5 lines / single
  file / zero logic)
- Every commit gate stated explicitly on every commit
- External adversarial reviewers (a different model than the Lead's) when configured

The user can opt back to lighter review mid-flow ("normal review is fine") —
rigor is default-on, not mandatory-on.

## What still applies under force-full mode

- `verify-first` for any factual claim
- Every hook still fires
- User override mid-flow: "skip review" / "just ship" → obey

## Common rationalizations to reject

| Excuse | Reality |
|--------|---------|
| "Task is trivial, Define is overkill" | User invoked `/rolepod-full` precisely to disable that judgment. Run it. |
| "User probably meant just Build" | If they wanted just Build they'd type the task without `/rolepod-full`. Read the directive literally. |
| "I'll merge Define + Plan into one turn to save time" | Each phase has its own exit evidence. Run them sequentially. |
