---
name: <skill-name>
description: <one-paragraph trigger + scope. Describe when to apply. Keep under 250 chars.>
---

# <Skill Title>

<One-paragraph framing. State the core principle and why this skill exists. Tie to a concrete failure mode that the skill prevents. Cite research / production data where it sharpens authority (e.g. arXiv paper, DAPLab, Meincke 2025 — N=28k LLM persuasion study where structured framing moved compliance 33%→72%).>

## Iron Law

<EXTREMELY-IMPORTANT>
1-3 absolute non-negotiable rules. Use second person. Each rule must be testable
post-hoc ("did you do X?" → yes/no). No softeners ("try to", "consider",
"usually"). ห้ามฝืน — these rules do not bend for time pressure / "simple change"
/ "I already know" rationalizations.

Example shape:
1. NEVER <action> without <precondition>.
2. ALWAYS <action> before <commit / ship / declare-done>.
3. If <signal> → STOP and <recovery>. No exceptions.
</EXTREMELY-IMPORTANT>

## Red Flags — you are about to skip this skill

If you catch yourself thinking any of these, the skill is firing correctly — do
not override. Run the skill anyway.

| Red flag (your thought) | What it actually means |
|-------------------------|------------------------|
| "I'll do <skill action> after the code" | You will not. After-the-fact <action> proves nothing. |
| "This case is too simple to need <skill>" | 41% of agentic-LLM failures land in 'trivial' diffs (DAPLab). |
| "I already know the answer" | Confirmation bias — skill exists to surface what you missed. |
| "Time pressure, skip just this once" | Skip cost is unbounded; run cost is fixed. |
| "Pattern doesn't apply here" | Pattern-matching from training is unreliable; verify against rule. |

3-5 rows. Tailor to the skill's specific failure modes.

## When to use

<Bulleted list of concrete triggers. When does this skill fire?>
<Bulleted list of explicit skip cases. When NOT to fire?>

## How to apply

<Numbered steps or sub-sections. Concrete, testable, with examples.>

### 1. <step>

<body>

### 2. <step>

<body>

## Common mistakes

<Bulleted list of failure modes seen in practice.>

## Quick reference

<Cheat-sheet table or numbered list — the thing you reach for under pressure.>

## Common Rationalizations

When you're tempted to skip this skill, watch for these excuses:

| Excuse | Reality |
|--------|---------|
| "<excuse 1>" | <reality 1> |
| "This is a simple change, doesn't need <skill>" | Bugs hide in simple changes too — DAPLab data shows 41% of agentic-LLM failures land in 'trivial' diffs. |
| "I already know the answer" | Confirmation bias — the skill exists to surface what you didn't think of, not to repeat what you did. |
| "Time pressure, skip just this once" | Tech debt compounds; 5 minutes saved at write time costs 50 minutes of debugging later. |

Default response when rationalizing: run the skill anyway. Cost of running it is bounded; cost of skipping when you needed it is not.

<!--
Voice-engineering notes for skill authors (do not include in final SKILL.md):

- "Iron Law" + <EXTREMELY-IMPORTANT> tag: research-backed persuasion framing.
  Meincke 2025 (N=28k) found structured authority+commitment framing moved LLM
  compliance from 33% to 72%. Apply sparingly — only for the 1-3 non-negotiable
  rules per skill. Inflation kills the signal.
- "Red Flags" section: pre-empts the exact rationalizations users invent to skip
  the skill. Phrase as the user's *own thought* so the skill catches them
  red-handed.
- Cite research / production data where applicable (DAPLab, arXiv 2402.13521,
  Meincke 2025). Citations build authority without inflating length.
- Preserve existing skill structure (when-to-use / how-to-apply / common-mistakes
  / common-rationalizations). Iron Law + Red Flags are *additions*, not replacements.
- Length target: skill grows ~15-25 lines vs un-retrofitted version.
-->
