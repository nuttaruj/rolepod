---
name: write-spec
description: Use when turning a fuzzy goal, half-stated feature, or vague request into a sharp implementation spec. Discovery dialogue first, then design, then user approval, then a compact contract. Phase = Define.
when_to_use: when the user request is non-trivial and the goal, scope, success criteria, or risk surfaces are not already pinned down in the conversation or in the repo
tier: 1
phase: define
---

# Write Spec

Convert a vague request into a sharp spec the next phase executes against: discovery in frontier rounds → design alternatives → user approval → compact contract.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER skip the spec when the goal, scope, or success criteria are ambiguous, or when the request touches a high-risk surface (auth, billing, payments, credits, migration, data deletion, secrets, tokens, crypto, permissions, security).
2. NEVER start implementation before the user approves the design direction (Gate 1).
3. ASK discovery questions in FRONTIER ROUNDS: each round carries every question whose prerequisites are settled; a question depending on an open answer waits for the next round. RECOMMEND a default per question — the user confirms or overrides. Facts are never questions: anything the codebase or docs can answer is researched, not asked.
4. NEVER ship a spec that contains placeholders, contradictions, or untested assumptions about the user's intent.
5. A spec saved as a file needs a second approval on the written file itself (Gate 2) — verbal agreement and the written file drift apart.
</EXTREMELY-IMPORTANT>

Fires on a COMMISSION, never on musing: the user exploring an idea ("what if we…", "would X be worth it?" in any language) gets a discussion, not a spec interview; the router offers the spec once when the idea firms up.

## When to use

- A feature with vague boundaries · multiple valid implementations whose choice changes the diff · a high-risk surface · no existing pattern in the codebase · "build me X" without details.

Skip when:
- A one-line fix with an obvious diff · the user supplied a written spec · the user said "skip spec" / "just write the code".

## Boundary

Owns: WHAT / WHY / scope / non-goals / success criteria / risk surfaces / chosen direction / user approval.

Does not own: file-by-file order · agent file ownership · exact test commands per task · editing code.

Hand off:
- Approved spec → `write-plan`. A complete user-supplied spec → straight to `write-plan`.

## Workflow

Inputs: the exact request (literal quote) · relevant repo state (existing patterns, prior decisions) · constraints already stated (deadline, stack, no-touch zones) · high-risk surfaces likely touched. Repeat feature: read the most recent `docs/rolepod/specs/<feature>-*.md` and treat its Desired behavior as a *hypothesis* for today's Current behavior — verify against the code, never re-derive prior state from a blank slate.

### 1. Frame the goal

One sentence for the goal, 2-3 likely constraints, every high-risk surface flagged. The goal needs an "and" → possibly several specs: `references/scope-splitting.md`. Slices cannot even be listed because unresolved decisions block the view → `references/chart-work.md`: chart the decisions first, spec each slice after.

### 2. Discovery dialogue

Model the open decisions as a tree — each answer unblocks the questions hanging off it. Ask in **rounds**: number every question on the current frontier and present the round together; a question whose answer depends on one still open belongs to the next round. Each question must change the implementation if the answer changes — skip obvious ones. A long frontier is grouped by topic and asked in full, never trimmed.

Use the native question UI when the CLI has one; otherwise numbered questions with lettered options, the recommended default marked, compact answers accepted — `1a 3c`, or `defaults` for every recommendation. Done when the frontier is empty and no scout is still out.

**Recommend a default per question** — the simplest viable answer, stated alongside it. Faster than open-ended and forces a position you can defend.

A question the codebase can answer → explore instead. While a round is out, that wait is free wall-clock: dispatch a scout on the researchable unknowns in parallel — a running scout is itself an unsettled prerequisite, so only its downstream questions wait.

**Visual companion for UI-shape questions.** Layout, flow, or visual hierarchy with `rolepod-uiproof` installed → offer a browser mockup or reference screenshot (`/verify-ui`, `/visual-diff`) before the text question. Interaction FEEL → a disposable single-file HTML demo (inline CSS/JS, mock data, no server) on a throwaway `spike/` branch; the user clicks the options before answering. Decision + branch pointer land in the spec; the branch is NEVER merged.

Unsure which questions change the implementation → `references/question-bank.md`.

### 3. Present 2-3 approaches

One per **lens** so they differ for real: **minimal** (smallest diff, maximum reuse) · **clean** (the boundary a maintainer would want, more files) · **pragmatic** (the seam between). Tradeoffs: complexity, blast radius, reversibility, cost. Recommend one; simplest viable wins by default — the clean lens earns its place by naming what minimal costs later, so `## Rejected approaches` records a real trade-off, not `None`.

The approach adds or changes a DB table / migration, a public API contract, or a module boundary → ONE `system-architect` dispatch drafts the three lenses (returned inline, no file) and the Lead judges; anything else stays Lead-authored.

**ADR only when all three hold:** hard to reverse · surprising without context · a real trade-off between genuine alternatives. Any one missing → the spec is the record. Save to `docs/adr/NNNN-<slug>.md` (context, decision, consequences — one page).

### 4. Self-review the draft

Scan for: placeholders (`[[FILL: …]]`, `TODO`, `tbd`) · contradictions between sections · ambiguous wording ("maybe", "should", "if needed") · a Success criterion with no "proven by", or proven at a seam only the implementation can reach, or naming a command that does not exist yet without saying so — pair each with a real or explicitly-new command / observation a caller can reach · a technical claim behind the chosen approach with no verifiable pointer (file:line, commit, or URL + date) · scope creep · over-engineering for hypothetical needs.

### 4b. Cross-family critique — questions only, before Gate 1

Pool enabled (opt-in; off → skip silently) and the spec is R3+ / high-risk (or the user asks) → hand the draft plus the Q&A ledger to a cold reader from another CLI: `rolepod-cross-family --kind critique --brief spec-draft.md` returns ≤5 items ranked by implementation risk (`QUESTION` / `AMBIGUITY` / `MISSING`, or `NO FURTHER QUESTIONS`). Settle from the repo what you can, then ONE extra §2 round with the rest; one line under **Open questions**. Never blocks a spec. Protocol: `references/question-bank.md` §Cross-family critique.

### 5. Gate 1 — direction approval

Present the chosen approach + rationale. Wait for accept / edit / reject. No contract before Gate 1 passes.

### 6. Produce the contract

Fill `templates/spec-template.md` — every section resolved. Repeat feature: a section that did not move reads `Unchanged — <prior spec> §<name>` (Goal, User / actor, Non-goals, Constraints, Chosen approach, Rejected approaches may inherit; Current behavior, Desired behavior — the delta — Success criteria, High-risk surfaces, Open questions are always fresh).

Then the **spec-lint** on the filled text (piped in inline mode, the saved file in file mode): `grep -niE '\[\[FILL:|TODO|TBD'` must print nothing; a printed line or a grep error is a lint failure, never a silent pass (it catches an unfilled marker or stray TODO/TBD, never legitimate angle brackets like `<h1>` / `List<T>`, and not vague wording).

- One-session work → inline in chat; Gate 1 is the only approval. Default when unsure.
- Multi-session, high-risk surface, or repeat feature → save to `docs/rolepod/specs/<feature>-YYYY-MM-DD.md` (optional `-vN` / `-draft`). **`docs/rolepod/` is private by default:** before the first save, `grep -qx 'docs/rolepod/' .gitignore || echo 'docs/rolepod/' >> .gitignore` — a repo that deliberately tracks its working docs creates `.rolepod/docs-tracked`. Plans and hand-offs follow the same rule. Proceed to Gate 2.

### 7. Gate 2 — file review (file mode only)

After saving: spec-lint on the file (must print nothing) and the anchor check — `for h in 'Non-goals' 'Current behavior' 'Desired behavior' 'Success criteria'; do grep -q "^## $h" <spec> || echo "missing ## $h"; done` — must print nothing (the next repeat-feature spec seeds from these four headings; a renamed or numbered heading cannot be found).

Then ask the user to read the FILE and confirm, not the chat. Catches word drift (chat "soft delete", file "delete"), implicit edge cases ("except admin" omitted), reconsideration on seeing the concrete shape. Patch and re-confirm if asked. Hand off only after Gate 2 passes.

## If a matching Rolepod agent is available

- Scope, user stories, priorities, cost / ROI framing: the USER through §2 — the user is the product owner.
- `system-architect` — API / data-model / integration design.
- `content-strategist` (`audience: dev`) — ADRs and durable spec artifacts.

Brief: the request, the answers so far, the approval gate the user expects.

## If no matching agent is available

Execute the checklist directly as Lead: quote the request → goals + non-goals → high-risk surfaces → the smallest question set → 2-3 approaches with tradeoffs → recommend one → Gate 1 → §6 inline-vs-file, then the matching gate.

## Output

The spec template is the canonical artifact: `templates/spec-template.md` — the contract `write-plan` consumes. Inline vs file and the matching gate: §6.

## References

Load only when needed:
- `references/question-bank.md` — question types, skip rules, cross-family critique protocol.
- `references/scope-splitting.md` — a request too big for one spec.
- `references/chart-work.md` — chart blocking decisions before slicing.
- `examples/spec-examples.md` — two good/bad pairs (one high-risk, one not).

## Hard stops

- A round's answers did not close the ambiguity → name the one thing unresolved and offer two concrete framings; still unresolved → stop and record what is needed to resume; never re-ask the same question in a new shape.
- User declines every approach → stop, report what is blocking.
- High-risk surface without a security / migration / audit plan → add it (or delegate to `security-engineer` / `system-architect`) before handing off.

## Next phase

- `write-plan` with the approved spec.
- If `write-plan` is not available, hand off an implementation outline: files to touch, ordered tasks, test plan, risks, done criteria.
