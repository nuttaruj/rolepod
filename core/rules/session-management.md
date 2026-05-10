# Session Management

Read when: session getting long / context near limit / starting unrelated task / on wrong path.

## Core constraint

Context window fills fast. Performance degrades as it fills. Manage aggressively.

Anthropic best practice: "context window is the most important resource to manage."

## Commands

| Command | Use |
|---------|-----|
| `/clear` | Reset context. Use BETWEEN unrelated tasks. |
| `/rewind` (or `Esc Esc`) | Open rewind menu. Restore conversation/code/both to checkpoint. |
| `/compact <focus>` | Manual compaction with focus instruction. E.g. `/compact Focus on API changes` |
| `/btw` | Side question — answer in dismissible overlay, NOT in conversation history |
| `Esc` | Stop Claude mid-action. Context preserved → redirect. |
| `claude --continue` | Resume most recent session |
| `claude --resume` | Pick from session list |
| `/rename <name>` | Name session (e.g. `oauth-migration`) for later resume |

## When to `/clear`

- Switching to unrelated task
- Started talking off-topic, want to refocus
- Context filled with debugging dead-ends
- Corrected Claude 2+ times on same issue (clean context > polluted long context)

After `/clear` → write better initial prompt incorporating what you learned.

## When to `/rewind`

- Claude went wrong direction → restore to last good checkpoint
- Risky experiment → if fails, rewind and try different approach
- Want to branch — try Path A, rewind, try Path B, compare

Checkpoints persist across sessions. Close terminal → still rewind later.

**Limit**: checkpoints track only changes Claude made, NOT external processes (your manual edits, git ops, file system changes outside Claude). Not a git replacement.

## When to `/compact`

- Context >70% full but task still in progress
- Want to preserve key context while freeing space
- Use `/compact <focus>` to bias what survives

Customize compaction in CLAUDE.md:
```
When compacting, always preserve:
- Full list of modified files
- Test commands run
- Key architectural decisions made
```

## When to use subagent (vs main session)

Anthropic best practice: "subagents are one of the most powerful tools."

Subagent runs in **separate context** → reports back summary → main context stays clean.

| Task | Use subagent? |
|------|---------------|
| "Investigate how X works" (reads many files) | YES |
| "Find all callers of Y" | YES |
| "Review this code for edge cases" | YES |
| Implementing feature in current file | NO (Lead does it) |
| Quick file read | NO |

## Failure patterns to recognize

### Kitchen sink session
Started 1 task → drifted to unrelated → drifted back. Context = polluted.
**Fix**: `/clear` between unrelated tasks.

### Correction spiral
Claude wrong → correct → still wrong → correct again.
**Fix**: After 2 failed corrections → `/clear` + write better initial prompt.

### Infinite exploration
"Investigate X" without scope → reads 100 files → context full.
**Fix**: Scope narrowly OR delegate to subagent.

### Trust-then-verify gap
Plausible-looking implementation → doesn't handle edge cases.
**Fix**: Verification (tests/scripts/screenshots). Can't verify → don't ship.

### Over-specified CLAUDE.md
File >250 lines → Claude ignores rules in noise.
**Fix**: Prune. Each line: "would removing cause mistakes?" No → cut.

## Develop intuition

Anthropic guidance: "patterns aren't set in stone — develop intuition."

Sometimes:
- Let context accumulate (deep in 1 problem, history valuable)
- Skip planning (exploratory task)
- Vague prompt (want to see Claude's interpretation first)

Pay attention to what worked. Adjust.

## Common mistakes — DO NOT

- Keep correcting in polluted context — `/clear` and restart
- Forget `/clear` between morning bug-fix and afternoon feature
- Use main session for big investigation when subagent fits
- Treat checkpoint as git replacement (it's not)
- Over-rely on `/compact` — sometimes `/clear` + better prompt is better
