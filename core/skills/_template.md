<!-- Rolepod skill-authoring template + contract. -->
<!-- This file is maintainer tooling — it is NOT a skill. It has no skill -->
<!-- directory, so render.sh (which globs core/skills/*/) does not ship it -->
<!-- and the model cannot invoke it. Copy Part 1 to start or rebuild a -->
<!-- skill; follow Parts 2-6 to keep the lean surface intact. -->

# Rolepod Skill Authoring

A Rolepod skill is one `SKILL.md` spine plus optional supporting files. The
public surface is fixed: **Core 10 + the `rolepod-full` alias**. Do not add a
12th skill directory — `tests/static/lean-surface.sh` asserts exactly 11.
This guide is for upgrading the existing 11, not growing the count.

A skill must hold three properties at once:

1. **Standalone** — copied alone, the `SKILL.md` delivers 70-80% of the value.
2. **Lean by default** — supporting files load only when a pointer fires.
3. **Single-sourced** — every artifact shape lives in exactly one place.

---

## Part 1 — The SKILL.md skeleton

Copy this, delete the `<hints>`. Keep a phase skill ≤ 190 lines.

```markdown
---
name: <skill-name>
description: <when to apply + scope, one sentence. Phase = <Phase>.>
when_to_use: <the trigger condition, prose>
tier: 1
phase: <define|plan|build|verify|review|ship|recovery>
---

# <Skill Title>

<One-paragraph framing: the phase, what the skill converts, the failure
 mode it prevents.>

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER <action> without <precondition>.
2. ALWAYS <action> before <commit / ship / declare-done>.
3. If <signal> → STOP and <recovery>.
</EXTREMELY-IMPORTANT>

## When to use

- <concrete trigger>

Skip when:
- <explicit skip case>

## Boundary

Owns:
- <what this phase owns>

Does not own:
- <what a neighbouring phase owns>

Return / hand off:
- <condition> → `<skill>`.

## Inputs to gather

- <what the skill reads before acting>

## Workflow

### 1. <step>

### 2. <step>

## If a matching Rolepod agent is available

Delegate to the closest specialist:
- `<agent>` for <work>

## If no matching agent is available

Execute as Lead with this minimum viable checklist:
1. <step>

## Output

The <artifact> is the canonical artifact: `templates/<artifact>.md`. Do not
restate its shape here; the template is the single source.

## Examples

Non-blocking — read only when <the work is unclear>:
- `examples/<skill>-examples.md` — <what it contrasts>.

## References

Load only when the task needs it:
- `references/<technique>.md` — <when to reach for it>.

## Hard stops

- <condition> → stop, <recovery>.

## Full Rolepod enhancement

Full Rolepod improves this phase by adding <router continuity / agents /
hooks / tests>.

## Next phase

- If `<next-skill>` is available, continue there.
- If not, <terminal handoff / fallback>.
```

`lean-surface.sh` fails a phase skill that omits any of: `## Boundary`, a
no-agent fallback section, that fallback ≤ 25 lines, `## Full Rolepod
enhancement`, a `## Next phase` carrying a fallback or terminal handoff. It
also fails hard-dependency language ("Always delegate to", "Requires Rolepod
agents") and any phase skill over 190 lines.

---

## Part 2 — Supporting files: when to add, when not

Three optional folders sit beside `SKILL.md`:

```
<skill>/
  templates/    artifact shapes the skill fills
  examples/     good/bad contrast pairs
  references/   deep technique, loaded on demand
```

Add a file ONLY when it has a distinct job. The count is per-skill judgment,
not a quota. Lean caps (`lean-surface.sh` enforces):

- ≤ 4 supporting files per skill
- ≤ 5 for `debug-issue` and `finish-work` (the deepest skills)
- ≤ 3 for the `using-rolepod` router · 0 for the `rolepod-full` alias
- ≤ 36 supporting files total across all skills

Decide each folder on its own merit:

| Folder | Add when | Do NOT add when |
|--------|----------|-----------------|
| `templates/` | the skill produces a durable artifact a later phase consumes | the output is a short status, not an artifact |
| `examples/` | a good/bad contrast changes behaviour | the skill body already makes the bar obvious |
| `references/` | a sub-technique is real depth, distinct from the spine | the spine already covers it — a reference restating an inline table is bloat |

Variance is correct: `review-code` ships 2 files, `debug-issue` ships 5. If a
skill needs nothing, it ships nothing — the `rolepod-full` alias has zero.

---

## Part 3 — Pointer rules

A pointer in `SKILL.md` names a supporting file. Three rules:

1. **Skill-relative path.** Write `examples/foo.md`, not a repo-root path —
   the skill ships to a different absolute path per CLI. A pointer to another
   skill's file must be explicit: `using-rolepod/references/foo.md`.
2. **Conditional trigger.** "If the request is multi-system, read
   `references/scope-splitting.md`" — not a bare "see references/". The
   condition is what keeps default context lean.
3. **Non-blocking.** "For an example, see X" — never "you MUST read X first".
   The `SKILL.md` carries the 70-80%; supporting files are the +20-30%.

---

## Part 4 — The de-dup rule

A template is the SINGLE source of an artifact's shape. When a skill gains a
`templates/<artifact>.md`, DELETE the inline shape from `SKILL.md` and leave a
pointer. A shape that lives in both the template and the skill body will
drift. De-dup usually makes `SKILL.md` shorter, not longer.

---

## Part 5 — Examples file structure

Name it `examples/<skill>-examples.md`. It must:

- Hold **two scenarios**, each a good/bad pair of the same case. Vary the
  axis (e.g. one high-risk, one not) so the model does not over-fit one
  flavour.
- Fence each good and bad artifact in a `text` block — this keeps intentional
  placeholders (`TBD`, `<...>`) out of prose and renders them as literal
  samples.
- Carry a **"Why good wins"** table per scenario — `lean-surface.sh` greps
  for that literal heading in every `*-examples.md`.
- Open with a one-line "read the whole file — the contrast is the lesson"
  note so the model does not read one half alone. One line; do not expand it.

---

## Part 6 — Conventions

- **Iron Rule**: 1-4 absolute rules, second person, testable post-hoc, no
  softeners ("try to", "usually"). Structured authority framing measurably
  lifts compliance (Meincke 2025, N=28k) — reserve it for the few
  non-negotiables; inflation kills the signal.
- **Cite research** where it sharpens a claim (arXiv, DAPLab) — e.g. weak
  LLM test assertions, ~62% (arXiv 2402.13521).
- **Placeholders** belong only in `templates/` (`<hints>`) and in the bad
  half of an examples file (`TBD`). Never in a `SKILL.md` spine.
- After any skill change: `make render`, then
  `bash tests/static/lean-surface.sh`. Both must be clean before commit.
