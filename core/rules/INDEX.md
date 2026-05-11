# Rules Index

Global rules. Read on-demand when trigger fires. NOT auto-loaded.

## Trigger → File map

| Trigger | File |
|---------|------|
| About to `gh pr merge` / `git push` to tracked branch | `pre-merge-gate.md` |
| About to spawn reviewer (Codex/Gemini/qa-tester) | `reviewer-flow.md` |
| Task >5 files / multi-agent / non-trivial | `triage-deep.md` |
| Need caller/impact/symbol/rename/blast-radius | `code-intel.md` |
| Past decision / "what did we decide" | `code-intel.md` (MemPalace) |
| CLI tool guidance (gh/aws/gcloud/etc.) | `code-intel.md` (CLI) |
| When to fire each tool / reindex / lifecycle | `code-intel-workflow.md` |
| About to claim a fact / make recommendation | `verify-first.md` |
| About to verify a change (test/screenshot/log) | `verification.md` |
| Planning task / when/how to test | `testing.md` |
| Tone/language/output format | `communication.md` |
| Big feature / interview user | `communication.md` (interview) |
| About to edit code — pattern/abstraction question | `code-quality.md` |
| First time in unfamiliar project / `/init` | `new-project.md` |
| Session long / context near limit / wrong path | `session-management.md` |
| Stuck (Sonnet/Haiku Lead) / `/advice` | `advisor.md` |
| Choosing agent / multi-agent parallel | `team-org.md` |
| Subagent protocol questions | `agent-protocol.md` |

## How to read

Use Read with absolute path: `~/.claude/rules/<file>.md`.
Apply to current task. Do NOT echo full content back.

## Maintenance

Add rule only after a real mistake would have been prevented. Prune monthly.

- Rule must happen 100% of time → Hook (`.claude/settings.json`), NOT file
- Rarely needed → Skill (`.claude/skills/<name>/SKILL.md`), NOT file
