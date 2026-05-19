---
name: session-hygiene
description: Compatibility shim — `/clear`, `/compact`, `/rewind`, and task-switch session discipline now live in `manage-context`.
when_to_use: '"long session", "context near limit", "switching task", "wrong path", "/clear", "/compact", "/rewind"'
tier: 3
redirect_to: manage-context
---

# session-hygiene

Compatibility shim. Session commands and task-switch discipline now live in **`manage-context`**.

→ Open `core/skills/manage-context/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `manage-context` is not available

Minimum viable fallback:

1. `/clear` between unrelated tasks — do not let prior context bleed in
2. `/compact <focus>` mid-session when context is heavy but work is incomplete
3. `/rewind` (Esc Esc) to undo a recent path you regret
4. `/rename` + `claude --continue` to switch session focus while keeping history
5. Subagent for read-heavy lookups so the main context stays clean
6. Watch the context bar — yellow = act, red = it is already too late
7. Capture any non-obvious decision before /clear if MemPalace is installed
