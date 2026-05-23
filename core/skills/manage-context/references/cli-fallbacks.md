<!-- Load when the context-management command for your CLI is unclear. -->

manage-context's workflow names Claude commands. Each CLI has its own
context tools — use the row for the CLI you are running on.

## Context tools by CLI

| Need | Claude | Codex | Gemini | Cursor |
|------|--------|-------|--------|--------|
| Trim heavy context | `/compact <focus>` | summarize the thread, then continue | summarize, then continue | summarize, then new chat |
| Start fresh | `/clear` | new session, or `resume` a clean one | restart the context | new chat (chat menu) |
| Undo a recent path | `/rewind` | `fork` from an earlier point if available | restart from a summary | no native — restart with brief |
| Switch focus | `/rename` + `claude --continue` | resume the target session | new context with a brief | new chat with brief |

## The universal fallback
When a CLI lacks a native command, the fallback is always the same: write a
handoff brief (`templates/handoff-brief.md`), end the session, and start a
fresh one that reads the brief. The brief — not the CLI command — is what
makes the work resumable.

## Rule
Never assume a `/command` exists on the CLI you are running on. If unsure,
write the handoff brief and restart — that works everywhere.
