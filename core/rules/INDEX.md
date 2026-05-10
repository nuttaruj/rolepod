# Rules Index

Global rules. Read on-demand when trigger fires. NOT auto-loaded.

## Trigger → File map

| Trigger | Read file |
|---------|-----------|
| About to `gh pr merge` / `git push` to tracked branch | `pre-merge-gate.md` |
| About to spawn reviewer (Codex/Gemini/qa-tester) | `reviewer-flow.md` |
| Task >5 files / multi-agent plan / non-trivial work | `triage-deep.md` |
| Need caller/impact/symbol/rename/blast-radius | `code-intel.md` |
| Need past decision / "what did we decide" | `code-intel.md` (MemPalace section) |
| Need CLI tool guidance (gh/aws/gcloud/sentry-cli/etc.) | `code-intel.md` (CLI section) |
| When in workflow to fire each tool / reindex strategy / lifecycle | `code-intel-workflow.md` |
| About to claim a fact / make recommendation | `verify-first.md` |
| About to verify a change (test/screenshot/log) | `verification.md` |
| Planning task / when to test / how to test internally | `testing.md` |
| Question on tone/language/output format | `communication.md` |
| Big feature / want to interview user | `communication.md` (interview section) |
| About to edit code — pattern/style/abstraction question | `code-quality.md` |
| First time in unfamiliar project / `/init` question | `new-project.md` |
| Session getting long / context near limit / wrong path | `session-management.md` |
| Stuck on hard problem (Sonnet/Haiku Lead) / `/advice` | `advisor.md` |
| Choosing which agent for task / multi-agent parallel plan | `team-org.md` |
| Subagent protocol questions (verify-first / hand-off / manifest) | `agent-protocol.md` |

## How to read

Use Read tool with absolute path: `~/.claude/rules/<file>.md`
After reading, apply to current task. Do NOT echo full content back to user.

## Maintenance

Add rule only after real mistake would have been prevented. Prune monthly.

If a rule "must happen 100% of time" → consider Hook (`.claude/settings.json`), NOT rule file.
If guidance is rarely needed → consider Skill (`.claude/skills/<name>/SKILL.md`), NOT rule file.
