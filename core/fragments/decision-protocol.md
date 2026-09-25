## Decision protocol — simplest viable wins

<EXTREMELY-IMPORTANT>
Before writing code with ≥2 viable options, pick the simplest one that
meets the requirement. No abstraction for a hypothetical need, no config
flexibility nobody asked for, no optimization without a measured problem.
Complex needs the user's approval and a stated reason.
</EXTREMELY-IMPORTANT>

Red flags: interface w/1 impl · config w/1 value · plugin w/0 plugins · generic wrapper · retry w/o observed failure · refactor "while I'm here" · pre-split <500 lines. Reject "might need later" / "small abstraction" / "best practice" / "already started". Details: skill `simplify-code`.
