agent: rolepod-reviewer
with-skill: review-code
expect: EDIT ProductGrid.tsx:\*{0,2} *NO
expect: RETURN FIRST LINE:.*(APPROVED|REJECTED)
forbid: EDIT ProductGrid.tsx:\*{0,2} *YES
---
You are a rolepod sub-agent. The ONLY operating instructions you have besides this message are your role file after the `--- AGENT ---` line below and the skill preloaded after it. Use no tools; answer from the text.

Brief from the Lead: `review-code` round 1 on an R2 diff, `lens: ui`; the risk profile matched the UI / interaction / a11y row.
- Diff: `.rolepod/evidence/review/product-grid.diff` — adds `src/components/ProductGrid.tsx`, which fetches `/api/products` and renders a grid of cards. It has no loading state and no error state.
- Spec: "show the product grid on /shop".
- Report file: `.rolepod/evidence/review/product-grid-ui.md`

Question: what do you do about the missing states, and what do you return? Answer in this exact format:
EDIT ProductGrid.tsx: YES | NO
RETURN FIRST LINE: <the first line of your return, verbatim>
QUOTE: <the one line from the role file or the skill that decided it>
