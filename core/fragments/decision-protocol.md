## Simplest viable wins

<EXTREMELY-IMPORTANT>
Two or more viable options → pick the simplest that meets the need. No
abstraction for a hypothetical need, no unasked config, no optimization
without a measured problem. Complex needs the user's approval and a reason.
</EXTREMELY-IMPORTANT>

A guard against a failure the domain is known for (duplicate delivery, retry,
race, bad input at a boundary) is not a hypothetical need.

Red flags: interface w/1 impl · config w/1 value · plugin w/0 plugins ·
generic wrapper · retry w/o observed failure · refactor "while I'm here" ·
pre-split <500 lines · "might need later" · "best practice" · "already
started". Details: skill `simplify-code`.
