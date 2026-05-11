# Session Management

Read when: session long / context near limit / unrelated task / wrong path.

## Core constraint

Context window fills fast. Performance degrades as it fills.

Anthropic: "context window is the most important resource to manage."

## Commands

| Command | Use |
|---------|-----|
| `/clear` | Reset. Use BETWEEN unrelated tasks. |
| `/rewind` (`Esc Esc`) | Restore conversation/code/both to checkpoint |
| `/compact <focus>` | Manual compaction with focus |
| `/btw` | Side question — overlay, NOT in history |
| `Esc` | Stop mid-action. Context preserved. |
| `claude --continue` | Resume most recent |
| `claude --resume` | Pick from session list |
| `/rename <name>` | Name session for later resume |

## When `/clear`

- Switching to unrelated task
- Drifted off-topic
- Context filled with debugging dead-ends
- Corrected 2+ times same issue (clean > polluted)

After `/clear` → write better initial prompt with learnings.

## When `/rewind`

- Wrong direction → restore to last good checkpoint
- Risky experiment → fails → rewind
- Branch — try A, rewind, try B, compare

Checkpoints persist across sessions.

**Limit**: tracks Claude's changes only, NOT external processes (manual edits, git ops). Not a git replacement.

## When `/compact`

- Context >70% full + task in progress
- Use `/compact <focus>` to bias what survives

Customize in CLAUDE.md:
```
When compacting, always preserve:
- Modified files list
- Test commands run
- Architectural decisions
```

## Subagent vs main session

Anthropic: "subagents are one of the most powerful tools." Separate context → reports summary → main stays clean.

| Task | Subagent? |
|------|-----------|
| "Investigate how X works" (many files) | YES |
| "Find all callers of Y" | YES |
| "Review for edge cases" | YES |
| Implementing in current file | NO |
| Quick file read | NO |

## Failure patterns

**Kitchen sink** — 1 task → drift → drift back. Polluted. Fix: `/clear` between tasks.

**Correction spiral** — wrong → correct → still wrong → correct again. Fix: after 2 failed → `/clear` + better prompt.

**Infinite exploration** — "investigate X" no scope → 100 files. Fix: scope narrowly OR subagent.

**Trust-then-verify gap** — plausible-looking → misses edges. Fix: verification (tests/scripts/screenshots).

**Over-specified CLAUDE.md** — >250 lines → rules lost in noise. Fix: prune. Each line: "removing would cause mistakes?" No → cut.

## Develop intuition

Sometimes:
- Let context accumulate (deep in 1 problem)
- Skip planning (exploratory)
- Vague prompt (see Claude's interpretation first)

## Common mistakes — DO NOT

- Keep correcting in polluted context
- Forget `/clear` between morning bug-fix and afternoon feature
- Main session for big investigation when subagent fits
- Treat checkpoint as git replacement
- Over-rely on `/compact` when `/clear` + better prompt works
