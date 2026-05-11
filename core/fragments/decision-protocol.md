## Decision protocol — simplest viable wins

Fires BEFORE writing code with ≥2 viable options. Upstream of S1-S5.

<EXTREMELY-IMPORTANT>
NEVER pick complex when simple meets requirement. NEVER add abstractions for hypothetical needs. NEVER add config flexibility nobody asked for. NEVER pre-optimize without measured evidence. Default: SIMPLEST viable wins. Complex needs user approval + reason.
</EXTREMELY-IMPORTANT>

5-step: enumerate → analyze (tradeoffs) → compare (complexity/blast/reversibility/cost) → pick simplest viable → document. Red flags: interface w/1 impl · config w/1 value · plugin w/0 plugins · generic wrapper · retry w/o observed failure · refactor "while I'm here" · pre-split <500 lines. Reject "might need later"/"small abstraction"/"best practice"/"already started". Details: skill `code-simplification`.
