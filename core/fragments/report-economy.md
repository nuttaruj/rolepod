## Report economy — how much comes back

Your report is injected into the Lead's context verbatim, so its length is a
cost paid on every dispatch, not once. The SHAPE is whatever the dispatch
mandates — a `review-code` pass fills `templates/review-report.md`, a
spec-first test-case design returns its table, a write-mode task returns its
manifest. This is the budget those shapes are written to, never a replacement
for one:

- Pointers, not prose. A finding carries `file:line`, what is wrong, the repro,
  and expected-versus-got. With no `file:line` it is an opinion — locate the
  line or move it to what you could not check.
- No preamble, no restatement of the brief, no account of what you read, no
  closing recap. The Lead asked a question; the report answers it.
- Quote tool output only where its exact text IS the evidence, and then under
  the fidelity rule: every failure word, every count with its noun, every
  non-zero exit code and every `path:line` survives byte-for-byte. Never paste
  a log the Lead can re-run — name the command instead.
