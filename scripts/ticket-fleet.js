// ticket-fleet — the scripted build+review fleet for `rolepod-ticket fleet`
// (spec: lead-cost-no-pause-2026-09-22, Task 5, candidate B). Runs on the
// one CLI with a workflow tool, on top of Task 1's `rolepod-ticket`.
//
// args = { tasks: [{ n, brief, worktree, role, reviewers: [...] }] }
// (as printed by `scripts/ticket.sh fleet <plan>` — brief/worktree are
// absolute paths, role/reviewers come straight off the brief's own
// "## Owner" / "## Reviewers" lines, so this script never re-derives them).
//
// Per task, in ONE pipeline (no barrier between tasks — task A can be in
// Fix while task B is still in Build):
//   Build  — the task owner, agentType:'rolepod:<role>', builds in its
//            worktree. Prompt = start's own dispatch line (brief + worktree
//            paths) plus one line telling it NOT to dispatch its own
//            reviewers (this script does that instead — the probe found a
//            workflow agent has no Agent tool, so it couldn't anyway).
//   Review — one call per entry of task.reviewers, in parallel (a genuine
//            barrier: the fix decision below needs every verdict at once).
//            Each reads the worktree's diff and writes its report under the
//            main checkout's .rolepod/evidence/review/, same convention
//            `rolepod-ticket integrate` already scans.
//   Fix    — ONLY when a reviewer returned blocking findings: ONE more
//            owner call with them, then ONE re-check by each flagging
//            reviewer (never a second full review round — the two-round
//            budget, as control flow instead of owner judgment).
// No scripted verifier stage: the owner loops on the brief's ## Check as it
// builds and runs ## Command once itself before returning; the verifier is
// `rolepod-ticket integrate`, which re-runs the Command and the Proof
// before the commit command is printed.
//
// Tier (probe-verified recipe, docs/rolepod/handoffs/ticket-fleet-probe-
// 2026-09-22.md #5): a `// tier-reason:` comment, agentType dynamic via a
// TEMPLATE LITERAL (never `'rolepod:' + x` concatenation — the fleet-tier
// hook's per-call pin check only resolves the closed 'rolepod:' portion of
// a concatenation and never sees the rest, so that call reads as unpinned
// on a fan-out and risks a bare-fan-out deny under a strong/unknown Lead;
// a template literal's non-quote lead character is trusted like a variable
// instead), a literal `model:` on the owner/fix (balanced) calls, and NO
// literal strong model anywhere — the review stage's own tier comes from
// the reviewer role's frontmatter, never a script pin.
//
// tier-reason: dynamic agentType per task/reviewer role from args — every
// role renders its own frontmatter tier; no fleet-wide model inherit here.

// meta.name carries "review" on purpose (never rename to drop it): the
// round breaker's Workflow classifier (scripts/cross-family.sh --rounds)
// reads agent_types off the dispatch-log line, which is EMPTY for every
// call here (agentType is a template literal, invisible to the logger's
// straight-quote-only extractor by design — see the tier-reason above) and
// falls back to a `review|verif|audit` match on this very name; without it
// the whole launch is silently dropped from the round count instead of
// counting as ONE, as docs/hooks.md's "Ticket helper" section promises.
export const meta = {
  name: 'ticket-review-fleet',
  description: 'Build + review every ready ticket-loop task, one launch',
  phases: [
    { title: 'Build', detail: 'the task owner builds in its own worktree' },
    { title: 'Review', detail: 'one reviewer per task role, in parallel' },
    { title: 'Fix', detail: 'one owner fix call, only on blocking findings' },
  ],
}

const OWNER_SCHEMA = {
  type: 'object',
  properties: {
    status: { type: 'string' },
    summary: { type: 'string' },
  },
  required: ['status'],
}

// report/blocking/tail are all capped: the live run (wf_3a5a836e-cbc) came
// back with each reviewer's FULL 1.5-2.5 KB report text in `report` instead
// of its path — landing in the Lead's context, the exact cost this plan
// removes. A path and a one-line-per-finding `blocking` stay small; the
// findings themselves live in the report file, never in the returned object.
const REVIEWER_SCHEMA = {
  type: 'object',
  properties: {
    verdict: { type: 'string' },
    blocking: {
      type: 'array',
      items: { type: 'string', maxLength: 120, description: 'One BLOCKER/MAJOR finding, file:line plus <=120 chars — never the full explanation.' },
    },
    report: {
      type: 'string',
      maxLength: 300,
      description: 'The absolute path of the report file just written — the path only, never its contents.',
    },
  },
  required: ['verdict', 'blocking'],
}

// The main checkout's root, from the brief's own path — every brief `start`
// writes lands at exactly "<repo-root>/docs/rolepod/handoffs/<slug>.md", so
// this is a pure string op (the script has no filesystem access to `git`
// this itself), never a second field the CLI's `fleet` output has to carry.
function repoRootOf(brief) {
  const marker = '/docs/rolepod/handoffs/'
  const i = brief.indexOf(marker)
  return i >= 0 ? brief.slice(0, i) : brief
}

function reportPath(task, role) {
  return `${repoRootOf(task.brief)}/.rolepod/evidence/review/t${task.n}-${role}.md`
}

function ownerPrompt(task) {
  return `${task.brief} ${task.worktree}\ndo not dispatch reviewers — the script does\n` +
    'Loop on the brief\'s ## Check after each edit; run the ## Command once when the diff is ' +
    'final, before you return.'
}

function reviewPrompt(task, role) {
  return `Review Task ${task.n}'s diff in the worktree ${task.worktree} against its brief ` +
    `${task.brief}. Write your full findings to ${reportPath(task, role)} (a VERDICT: line ` +
    'first) — that file is where the explanations live. Return only: the verdict, one short ' +
    'line per BLOCKER/MAJOR as blocking (file:line plus <=120 chars each, never the full ' +
    'explanation), and the report file absolute path — nothing else in any of the three.'
}

function recheckPrompt(task, role, findings) {
  return `Re-check Task ${task.n} in the worktree ${task.worktree} — your prior blocking ` +
    `findings: ${findings.join('; ')}. Update the report at ${reportPath(task, role)} with the ` +
    'full re-check. Return only: the updated verdict, any findings still blocking in the same ' +
    'one-line-each shape, and the report file absolute path.'
}

function fixPrompt(task, flagging) {
  const lines = flagging.map((f) => `${f.role}: ${f.result.blocking.join('; ')}`).join(' | ')
  return `Task owner for Task ${task.n}, worktree ${task.worktree}. Fix these blocking review ` +
    `findings, ONE round, then stop: ${lines}\n` +
    'Loop on the brief\'s ## Check after each edit; run the ## Command once when the diff is ' +
    'final, before you return.'
}

async function processTask(prev, task) {
  const role = task.role
  const reviewers = task.reviewers || []

  const owner = await agent(ownerPrompt(task), {
    agentType: `rolepod:${role}`,
    model: 'sonnet',
    effort: 'low',
    phase: 'Build',
    schema: OWNER_SCHEMA,
  })

  let reviewResults = []
  if (reviewers.length) {
    reviewResults = await parallel(reviewers.map((r) => () =>
      agent(reviewPrompt(task, r), {
        agentType: `rolepod:${r}`,
        phase: 'Review',
        schema: REVIEWER_SCHEMA,
      })
    ))
  }

  const flagging = reviewers
    .map((r, i) => ({ role: r, result: reviewResults[i] }))
    .filter((x) => x.result && Array.isArray(x.result.blocking) && x.result.blocking.length > 0)

  let fixResult = null
  let recheckResults = []
  if (flagging.length) {
    fixResult = await agent(fixPrompt(task, flagging), {
      agentType: `rolepod:${role}`,
      model: 'sonnet',
      effort: 'low',
      phase: 'Fix',
      schema: OWNER_SCHEMA,
    })
    recheckResults = await parallel(flagging.map((f) => () =>
      agent(recheckPrompt(task, f.role, f.result.blocking), {
        agentType: `rolepod:${f.role}`,
        phase: 'Review',
        schema: REVIEWER_SCHEMA,
      })
    ))
  }

  const verdicts = reviewers.map((r, i) => {
    const fi = flagging.findIndex((f) => f.role === r)
    const rc = fi >= 0 ? recheckResults[fi] : null
    return {
      role: r,
      verdict: reviewResults[i] ? reviewResults[i].verdict : null,
      blocking: reviewResults[i] ? reviewResults[i].blocking : [],
      recheck: rc ? rc.verdict : null,
    }
  })

  const reports = reviewResults.filter(Boolean).map((r) => r.report).filter(Boolean)

  log(`Task ${task.n}: ${owner ? owner.status : 'unknown'}, ${reviewers.length} reviewer(s)`)

  return {
    n: task.n,
    status: (fixResult && fixResult.status) || (owner && owner.status) || 'unknown',
    verdicts,
    reports,
  }
}

const tasks = (args && args.tasks) || []
const results = await pipeline(tasks, processTask)
log(`fleet: ${results.filter(Boolean).length}/${tasks.length} task(s) done`)
return results
