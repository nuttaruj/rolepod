<!-- Maintainer tooling, not a skill: render.sh ships only core/skills/*/. -->

# Writing a Rolepod skill

A skill is the work steps a model follows without friction. Write it so it holds three properties:

1. **Standalone** — copied alone, `SKILL.md` runs the whole workflow.
2. **Lean** — every line changes what the model does; branch-only material waits behind a pointer.
3. **Single source** — each meaning lives in one place; everything else points at it.

## The minimal skeleton

```markdown
---
name: <skill-name>
description: <what it does + the phrases that trigger it, one sentence>
---

# <Skill Title>

<One line: what this skill turns into what.>

## Skip when

- <case where the default path is wrong>

### 1. <Step>

<The action.> Done when: <a condition the model can check>.

### 2. <Step that delegates>

Dispatch `<role>` with <the brief>. Done when: <its return is checked>.
No subagents → the Lead does it.

## Guardrails

- <Positive target>. Never <the hard line it protects>.

For <condition>, read `references/<topic>.md`.

## Next phase

- `<next-skill>` with <what it hands over>.
- If `<next-skill>` is not available, <the fallback or terminal hand-off>.
```

Required: frontmatter `name` + `description`, the one-line framing, numbered steps each ending in a done-when, `## Next phase` with the "not available" fallback.
Optional: up to 3 guardrails, each paired with its positive target; `## Skip when`; reference pointers.
A step that delegates names its role in one line, plus the line "No subagents → the Lead does it."
Add another frontmatter key only when a CLI or script reads it.

## The disclosure test

Inline what every run needs. Point at what only some runs reach.
A pointer names its trigger and a skill-relative file: "A request spanning several systems → `references/scope-splitting.md`."
The pointer is optional reading; the step still works without it.
A template is the single source of an artifact's shape: the step names every section in the template's words, and the template adds only the layout.

## The writing levers

- **Positive target first.** Write the behaviour you want ("write one-line comments"). A prohibition earns a line only as a hard guardrail, and it sits beside its positive target.
- **Pretrained leading words.** Reach for a word the model already knows (_red_, _tight_, _seam_, _tracer bullet_) over a coined code. R0–R4 stay, each with its short gloss at first sight; other codes stay only where a hook or script prints or parses them.
- **One directive per line.** Split a sentence that chains clauses into separate lines.
- **Sharp done-when.** A checkable, exhaustive condition ("every caller accounted for") pulls the legwork; a vague one ("understood") invites premature completion.
- **Rule over mechanism.** State the rule and the command that does it. Hooks print their own message when they bite, so the skill leaves out which hook fires, exit codes, windows, version history and measurements.

## Pruning

- **One source per meaning.** Shared mechanics live in `core/fragments/` and arrive through `{{INCLUDE: core/fragments/<name>.md}}` on a line of its own.
- **The environment is a source of truth.** Leave one-command lookups (`--help`, config, the directory layout) to the environment; write down what looking cannot find — the reason, the unwritten convention, the gotcha.
- **Delete no-ops.** A sentence the model already obeys by default goes, whole.
- **No sediment.** A line that no longer bears on the work goes when you touch its section.
- **No ritual.** No intro beyond the framing line, no section that restates another, no "read the whole file" preamble.

## User decision points

Where a step needs the user's judgment (spec direction, plan shape, ship path, a debug hypothesis), offer 2–3 viable options with a one-line trade-off each and recommend one. The user picks; the skill proceeds.
Mechanical choices (a detected mode, a routing table) take the default without asking.

## Examples files

Name it `examples/<skill>-examples.md`. It holds two scenarios, each a good/bad pair of the same case, on different axes (one high-risk, one not).
Fence each artifact in a `text` block, so a placeholder in the bad half reads as a sample.
Close each scenario with a **Why good wins** table.
Placeholders belong only in `templates/` and the bad half of an example.

## Before you commit a skill change

1. `make render && bash tests/static/lean-surface.sh` passes.
2. A changed exit, branch or verdict line is probed: `tests/probes/run.sh <case>` puts the rendered skill alone in front of a cheap model and asks what it does next. A wrong answer is a text defect — fix the line.
