---
name: <skill-name>
description: <one-paragraph trigger + scope. When to apply. Under 250 chars.>
---

# <Skill Title>

<One-paragraph framing. Core principle + why skill exists. Tie to concrete failure mode skill prevents. Cite research where it sharpens authority (arXiv, DAPLab, Meincke 2025 — N=28k LLM persuasion study, structured framing moved compliance 33%→72%).>

## Iron Law

<EXTREMELY-IMPORTANT>
1-3 absolute non-negotiable rules. Second person. Testable post-hoc ("did you do X?" → yes/no). No softeners ("try to", "consider", "usually"). ห้ามฝืน — rules don't bend for time pressure / "simple change" / "I already know" rationalizations.

Example:
1. NEVER <action> without <precondition>.
2. ALWAYS <action> before <commit / ship / declare-done>.
3. If <signal> → STOP and <recovery>. No exceptions.
</EXTREMELY-IMPORTANT>

## Red Flags — about to skip this skill

Catch yourself thinking any of these → skill is firing correctly. Run it anyway.

| Red flag (your thought) | What it actually means |
|-------------------------|------------------------|
| "I'll do <action> after the code" | You won't. After-the-fact proves nothing. |
| "Too simple to need <skill>" | DAPLab: 41% of failures in 'trivial' diffs. |
| "I already know" | Confirmation bias — skill surfaces what you missed. |
| "Time pressure, skip just this once" | Skip cost unbounded; run cost fixed. |
| "Pattern doesn't apply here" | Pattern-matching from training unreliable; verify rule. |

3-5 rows. Tailor to skill's failure modes.

## When to use

<Concrete triggers when skill fires.>
<Explicit skip cases when NOT to fire.>

## How to apply

<Numbered steps. Concrete, testable, with examples.>

### 1. <step>

### 2. <step>

## Common mistakes

<Failure modes seen in practice.>

## Quick reference

<Cheat-sheet table — what you reach for under pressure.>

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "<excuse 1>" | <reality 1> |
| "Simple change, no skill needed" | DAPLab: 41% failures in 'trivial' diffs. |
| "I already know" | Confirmation bias. |
| "Time pressure" | 5 min saved = 50 min debugging. |

Default: run skill. Bounded cost.

<!--
Voice-engineering notes (do not include in final SKILL.md):

- "Iron Law" + <EXTREMELY-IMPORTANT>: Meincke 2025 (N=28k) — structured
  authority+commitment framing moved LLM compliance 33%→72%. Apply only for
  1-3 non-negotiable rules per skill. Inflation kills signal.
- "Red Flags": pre-empts exact rationalizations users invent. Phrase as user's
  *own thought* so skill catches red-handed.
- Cite research where applicable (DAPLab, arXiv 2402.13521, Meincke 2025).
- Preserve structure (when-to-use / how-to-apply / common-mistakes /
  common-rationalizations). Iron Law + Red Flags are additions, not replacements.
- Length: skill grows ~15-25 lines vs un-retrofitted.
-->
