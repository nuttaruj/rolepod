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

Copy this, delete the `<hints>`. Budget is BYTES, not lines, counted with
every `{{INCLUDE:}}` expanded: a phase skill ≤ 13 KB (`using-rolepod`
≤ 21.5 KB, `review-code` ≤ 19 KB, `rolepod-full` ≤ 3 KB and ≤ 80 lines, all
SKILL.md ≤ 131 KB), no prose line past 600 chars — `lean-surface.sh`
enforces each.

```markdown
---
name: <skill-name>
description: <when to apply + scope, one sentence. Phase = <Phase>.>
when_to_use: <the trigger condition, prose>
tier: 1
phase: <define|plan|build|verify|review|ship|simplify|recovery>
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

Hand off:
- <condition> → `<skill>`.

## Workflow

Inputs: <what the skill reads before acting, one line>.

### 1. <step>

### 2. <step>

## If a matching Rolepod agent is available

Delegate to the closest specialist:
- `<agent>` for <work>

## If no matching agent is available

Execute as Lead: <only the steps the Workflow above does not already state,
as one arrow chain — never a restatement of the Workflow>.

## Output

The <artifact> is the canonical artifact: `templates/<artifact>.md`. Do not
restate its shape here; the template is the single source.
<If the phase writes an evidence line: `{{INCLUDE: core/fragments/phase-log.md}}`
 followed by the one JSON shape this phase appends.>

## References

Load only when needed:
- `references/<technique>.md` — <when to reach for it>.
- `examples/<skill>-examples.md` — <what it contrasts>, good/bad pairs.

## Hard stops

- <condition> → <recovery>.

## Next phase

- `<next-skill>` <with what>.
- If `<next-skill>` is not available, <terminal handoff / fallback>.
```

`lean-surface.sh` fails a phase skill that omits any of: `## Boundary`, a
no-agent fallback section (≤ 25 lines), a `## Next phase` carrying a
fallback or terminal handoff. It also fails hard-dependency language
("Always delegate to", "Requires Rolepod agents"), any SKILL.md over its
byte cap, any prose line past 600 chars, and the retired `## Full Rolepod
enhancement` section (marketing prose a Lead never acts on — cut 2026-09).

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

- ≤ 5 supporting files per skill (`implement-plan`, `write-plan` 6)
- ≤ 3 for the `using-rolepod` router · 0 for the `rolepod-full` alias
- ≤ 44 supporting files total across all skills
- ≤ 34 KB of supporting bytes per skill, ≤ 176 KB total — the escape
  hatch is capped too, so a SKILL.md cut cannot migrate into references/

Decide each folder on its own merit:

| Folder | Add when | Do NOT add when |
|--------|----------|-----------------|
| `templates/` | the skill produces a durable artifact a later phase consumes | the output is a short status, not an artifact |
| `examples/` | a good/bad contrast changes behaviour | the skill body already makes the bar obvious |
| `references/` | a sub-technique is real depth, distinct from the spine | the spine already covers it — a reference restating an inline table is bloat |

Variance is correct: `simplify-code` ships 2 files, `implement-plan` ships 6.
If a skill needs nothing, it ships nothing — the `rolepod-full` alias has zero
supporting files and its own ≤3 KB / ≤80-line caps.

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
- The pointer in `SKILL.md` states the contrast in its own clause, so the
  file itself needs no "read the whole file" preamble (Part 7: no ritual).

---

## Part 6 — Conventions

- **Iron Rule**: 1-4 absolute rules, second person, testable post-hoc, no
  softeners ("try to", "usually"). Structured authority framing measurably
  lifts compliance (Meincke 2025, N=28k) — reserve it for the few
  non-negotiables; inflation kills the signal.
- **Multi-option at user-decision points**: when a workflow step needs
  human judgment (spec direction, plan shape, ship path, debug
  hypothesis), surface 2+ viable options with one-line trade-offs and
  recommend one — do not propose a single answer. The user picks; the
  skill then proceeds. Pattern refs: `write-spec` § "Present 2-3
  approaches", `finish-work` § "4-option finish menu". Exception:
  mechanical/auto-detected choices (router backend, manage-context
  mode, Q1-Q4 delegate gate).
- **Cite research** where it sharpens a claim (arXiv, DAPLab) — and cite
  only a number you have read in the cited source — e.g. authority framing
  lifts compliance (Meincke 2025, N=28k).
- **Placeholders** belong only in `templates/` (`<hints>`) and in the bad
  half of an examples file (`TBD`). Never in a `SKILL.md` spine.
- After any skill change: `make render`, then
  `bash tests/static/lean-surface.sh`. Both must be clean before commit.

---

## Part 7 — Lean rules (the 2026-09 cut, 164 → 126 KB raw / 166 → 129 KB expanded)

Every skill must hold three properties at once: **lean**, **works with the
others** (one vocabulary, clean hand-offs, no contradictions), **works
standalone** (loaded alone, on a CLI with no hooks). The rules that keep
all three:

- **Rule over mechanism.** State the rule and the command that does it.
  Never narrate which hook denies under which sub-condition, exit codes,
  harness timeouts, version history ("since v2.x"), or measurements — hooks
  print their own ≤600-char message when they bite. Where a hook carries a
  rule on Claude Code, one sentence makes the text the gate elsewhere: "On a
  CLI without hooks this section is the gate."
- **One definition per concept.** The R0-R4 ladder lives in `using-rolepod`;
  every other skill uses the 4-word gloss (R1 trivial edit · R2 one file +
  test · R3 multi-file · R4 high-risk) — enough to act on standalone. Shared
  mechanics live in `core/fragments/` (`phase-log.md`, the gate lists) and
  are `{{INCLUDE}}`d, never retyped.
- **No ritual.** No intro paragraph beyond one line; no section that
  restates another (`If no matching agent` is an arrow chain of what the
  Workflow does NOT already say); no "read the whole file" boilerplate; no
  diagram that duplicates the numbered steps under it.
- **One directive per line.** A paragraph that chains "— and …; a … (never
  …)" clauses is split into bullets. A model drops or mis-orders clauses in
  a 2,000-char line; three cross-CLI reviewers confirmed the risk.
- **When the byte cap bites**, in order: dedupe (grep whether the rule is
  stated elsewhere; point, don't restate) → move load-on-demand detail into
  `references/` (capped too) → name in the PR what the new doctrine
  replaces. Caps rise only with a measured incident.
