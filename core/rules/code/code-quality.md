---
paths:
  - "**/*.{ts,tsx,js,jsx,mjs,cjs}"
  - "**/*.{py,pyi}"
  - "**/*.{go,rs,rb,java,kt,swift,cs,cpp,c,h,hpp,php,lua,sh,zsh,bash}"
---

# Code Quality

Read when: about to edit / pattern question / abstraction question.

## Match existing style

Read 2-3 nearby files first. Match: naming (snake_case vs camelCase), file organization, error handling, comment style, import grouping.

Don't introduce new patterns "because better." Surgical = match local.

## Surgical changes

**Touch only what task requires.** Every line traces to user request.

DO NOT:
- "Improve" adjacent code / comments / formatting
- Refactor unbroken code
- Reformat to preferred style
- Add abstractions for single-use

DO:
- Notice unrelated dead code → **mention, don't delete**
- Remove imports/vars/fns YOUR changes orphaned
- Don't touch pre-existing dead code unless asked

## Simplicity floor

- DON'T add features beyond request
- DON'T add abstractions for single-use
- DON'T add config/flexibility nobody asked
- DON'T add error handling for impossible cases
- DON'T add backwards-compat shims when you can change code
- Validate only at system boundaries

Senior test: "overcomplicated?" Yes → simplify.

Deep: skill `simplify-code`.

## One source of truth

Search before adding: helper / util / constant / enum / schema / type / validation / pricing / behavior-affecting copy.

Use `gitnexus_query` or `rg` first. Found → reuse/extend. Not found → add.

## Comments

Default = no comments. Add ONLY when WHY non-obvious:
- Hidden constraint
- Subtle invariant
- Workaround for specific bug
- Surprising behavior

DO NOT comment:
- WHAT code does (names do that)
- Current task / fix / ticket reference (rots — PR description)
- "Used by X" / "Added for Y" (rots — code search finds)

## Anti-spaghetti

- Same pattern in 3+ places → centralize
- No "just this one place" for: auth / permissions / billing / credits / URL validation / redirects / SSRF / cookies / logging / retries / external API
- Dependency flow: features import shared, NOT reverse
- Separate presentation from logic
- API boundaries: BE models + FE types + tests agree

Deep: skill `anti-spaghetti`.

## Dead code

- Remove dead code / stale comments / xfail / unused compat YOU created
- Don't delete pre-existing dead code unless asked
- Mention in summary so user can decide

## Backwards compat

Default: keep public behavior backward compatible. Break only if user asks — flag in summary.

Internal code confirmed unused: delete cleanly. DO NOT:
- Rename `var` to `_var` to "hide" unused
- Add `// removed` comments
- Re-export removed types
- Keep deprecated paths "just in case"

## Security reflexes

Never log: secrets, tokens, PII, raw passwords, full credit cards.
Validate at boundaries: user input, external API responses, deserialization.
SSRF: never let user-controlled URL hit internal network without allowlist.
Auth: check at every endpoint, not "just this one place."

## New dependency

Justify:
- Not in stdlib / existing deps?
- Maintained (commits in last 6 months)?
- Reasonable size?
- License compatible?

All yes → add. Unsure → ask.

## File size

>500 lines → consider split. Don't pre-emptively. Don't split mid-task. Mention as future work.

## Multi-language project

- Match style **per language** — TS follows TS, Python follows Python
- Don't impose 1 language's idioms on another
- Cross-language contracts (API models, shared schemas):
  - Single source of truth
  - BE response + FE type + tests in sync
  - Use codegen (OpenAPI / Protobuf / Prisma)
- Integration test confirms FE/BE agree

## Common mistakes — DO NOT

- Refactor adjacent code "while I'm here"
- Add config option nobody asked for
- Validate for impossible scenarios
- Comment what code does
- Patch same bug in 3 places
- New dep without justification
- Break public API silently
