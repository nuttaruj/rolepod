<!-- Load when the context-management command for your CLI is unclear. -->

manage-context's workflow names Claude commands. Each CLI has its own
context tools — use the row for the CLI you are running on.

## Context tools by CLI

| Need | Claude | Codex | Gemini | Cursor |
|------|--------|-------|--------|--------|
| Trim heavy context | `/compact <focus>` | summarize, then start a fresh session with the brief | summarize, then start a fresh session with the brief | summarize, then new chat |
| Start fresh | `/clear` | new session, or `resume` a clean one | restart the context | new chat (chat menu) |
| Undo a recent path | `/rewind` | `fork` from an earlier point if available | restart from a summary | no native — restart with brief |
| Switch focus | `/rename` + `claude --continue` | resume the target session | new context with a brief | new chat with brief |

## The universal fallback
When a CLI lacks a native command, the fallback is always the same: write a
handoff brief (`templates/handoff-brief.md`), end the session, and start a
fresh one that reads the brief. The brief — not the CLI command — is what
makes the work resumable.

## Cross-CLI resume — the brief does not care which CLI reads it

The fresh session does NOT have to be the same CLI. Everything that makes
work resumable lives on disk and is CLI-agnostic: the handoff brief, the
plan artifact (checkboxes = position), spec, cohesion contract, evidence,
per-task commits. Skill names are identical across rolepod adapters, so
"read the handoff brief at <path> and continue the plan" routes the same
on claude / codex / cursor / gemini / antigravity / opencode — same
doctrine, same gates, and the same benefit applies to a fresh session on
the SAME CLI.

- Usage quota hit ≠ context full: quota kills the session regardless of
  context state — skip trimming, checkpoint what the gates allow, write the
  uncommitted state into the brief, switch.
- A CLI without a rolepod adapter resumes degraded: it can read the brief +
  plan (plain markdown), but gates and doctrine do not travel — route its
  diff back through a rolepod-equipped CLI for review before merging.
- The sibling-session soft warn may fire for up to 30 min after an abrupt
  switch (the dead session's lock is not yet stale). It is a warning, not
  a block — `ROLEPOD_ALLOW_SHARED_WORKTREE=1` silences the intentional case.

## Cross-CLI parallel tracks — sessions working CONCURRENTLY, not in relay

Resume is serial (one session ends, another continues). The same disk
artifacts also support CONCURRENT sessions: a parallel plan + cohesion
contract with a **Session split** section assigns each track to a CLI by
strength (e.g. API-heavy → codex, UI-heavy → claude), each session runs
its own Lead on its own track branch, and the integration session merges
in contract order. Protocol + kickoff prompts: the cohesion contract
template (write-plan) and "Session-split tracks" in implement-plan's
`references/subagent-dispatch.md`.

## Rule
Never assume a `/command` exists on the CLI you are running on. If unsure,
write the handoff brief and restart — that works everywhere.
