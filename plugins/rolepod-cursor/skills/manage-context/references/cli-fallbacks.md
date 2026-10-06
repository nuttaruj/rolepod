<!-- Load when the context-management command for your CLI is unclear. -->

manage-context's workflow names Claude commands. Each CLI has its own
context tools — use the row for the CLI you are running on.

## Context tools by CLI

| Need | Claude | Codex | Cursor |
|------|--------|-------|--------|
| Trim heavy context — same session, work carries on | `/compact <focus>` | `/compact` | `/summarize` (IDE chat and `cursor-agent`) |
| Hand off / start fresh — after the handoff brief is written | `/clear` | new session, or `resume` a clean one | new chat (chat menu) |
| Undo a recent path — drops work, never a trim | `/rewind` | `fork` from an earlier point if available | no native — restart with brief |
| Switch focus | `/rename` + `claude --continue` | resume the target session | new chat with brief |

## The universal fallback
When a CLI lacks a native command, write the handoff template to
`docs/rolepod/handoff.md` in the active repository, end the session, and start
a fresh one that verifies the checkout and disk state before reading the next
task and required predecessor state. The brief — not the CLI command — makes
the work resumable. An explicit user path, including a dated legacy handoff,
remains valid; never choose the newest handoff or overwrite a legacy file
automatically. A missing or wrong-checkout handoff means stop and ask for the
exact artifact or checkout state.

## Cross-CLI resume — the brief does not care which CLI reads it

The fresh session does NOT have to be the same CLI. Everything that makes
work resumable lives on disk and is CLI-agnostic: the handoff brief, next task,
required predecessor state, receipts/evidence, and per-task commits. Read
further artifacts only when a next-task decision, contract clause, or debug
fact is missing. Skill names are identical across rolepod adapters, so
"read the handoff brief at <path> and resume the owning phase" routes the same
on claude / codex / cursor / antigravity / opencode — same
doctrine, same gates, and the same benefit applies to a fresh session on
the SAME CLI.

- Usage quota hit ≠ context full: quota kills the session regardless of
  context state — skip trimming, checkpoint what the gates allow, write the
  uncommitted state into the brief, switch.
- Without native hooks or an adapter, hook enforcement is absent. If the CLI
  can load the standalone skills, follow their portable procedures and
  evidence gates; reviewer and Ship limitations still apply. If skills are
  unavailable, the handoff remains readable markdown, but do not claim the
  workflow gates ran.

## Parallel tracks across CLIs

Tracks as separate CLI sessions → the coordinating-parallel-tracks skill; no coordinating-parallel-tracks → one session runs the tracks in order.

## Rule
Never assume a `/command` exists on the CLI you are running on. If unsure,
write the handoff brief and restart — that works everywhere.
