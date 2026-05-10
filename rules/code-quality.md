# Code Quality

Read when: about to edit code / pattern question / abstraction question.

## Match existing style

Read 2-3 nearby files first. Match:
- Naming convention (snake_case vs camelCase)
- File organization (split vs monolithic)
- Error handling pattern
- Comment style
- Import grouping

Don't introduce new patterns "because they're better." Surgical = match local.

## Surgical changes

**Touch only what task requires.** Every changed line traces to user's request.

DO NOT:
- "Improve" adjacent code, comments, formatting
- Refactor unbroken code
- Reformat to your preferred style
- Add abstractions for single-use code

DO:
- Notice unrelated dead code → **mention, don't delete**
- Remove imports/vars/fns YOUR changes orphaned
- Don't touch pre-existing dead code unless asked

## Simplicity floor

Quick rules:
- DON'T add features beyond request
- DON'T add abstractions for single-use code
- DON'T add config/flexibility nobody asked
- DON'T add error handling for impossible cases
- DON'T add backwards-compat shims when you can change code
- Validate only at system boundaries

Senior engineer test: "overcomplicated?" Yes → simplify.

Deep guide: skill `code-simplification`

## One source of truth

Search before adding new:
- Helper / util function
- Constant / enum
- Schema / type
- Validation rule
- Pricing / billing logic
- Behavior-affecting copy

Use `gitnexus_query` or `rg` first. Found existing → reuse / extend. Not found → add.

## Comments

Default = no comments. Add ONLY when WHY is non-obvious:
- Hidden constraint
- Subtle invariant
- Workaround for specific bug (link issue if useful)
- Behavior that would surprise reader

DO NOT comment:
- WHAT code does (well-named identifiers do that)
- Current task / fix / ticket reference (rots — belongs in PR description)
- "Used by X" / "Added for Y flow" (rots — code search finds this)

## Anti-spaghetti

Quick rules:
- Same pattern in 3+ places → centralize
- No "just this one place" for: auth / permissions / billing / credits / URL validation / redirects / SSRF / cookies / logging / retries / external API
- Dependency flow: features import shared, NOT reverse
- Separate presentation from logic
- API boundaries: BE models + FE types + tests agree

Deep guide: skill `anti-spaghetti`

## Dead code policy

- Remove dead code / stale comments / xfail markers / unused compat paths YOU created
- Don't delete pre-existing dead code unless explicitly asked
- Mention pre-existing dead code in summary so user can decide

## Backwards compat

Default: keep public behavior backward compatible.
Break only if user asks — flag breaking change in summary.

For internal code with confirmed unused state: just delete cleanly.
DO NOT:
- Rename `var` to `_var` to "hide" unused
- Add `// removed` comments for deleted code
- Re-export removed types
- Keep deprecated paths "just in case"

## Security reflexes

Never log: secrets, tokens, PII, raw passwords, full credit cards.
Validate at boundaries: user input, external API responses, deserialization.
SSRF: never let user-controlled URL hit internal network without allowlist.
Auth: check at every endpoint, not "just this one place."

## New dependency

Adding a package? Justify:
- Functionality not in stdlib / existing deps?
- Maintained (commits in last 6 months)?
- Reasonable size (< few MB or accepts the cost)?
- License compatible?

If yes to all → add. If unsure → ask user.

## File size

When file grows >500 lines → consider split.
Don't pre-emptively split. Don't split mid-task.
Mention to user as future work.

## Multi-language project

Project mixing 2+ languages (e.g. Python backend + TypeScript frontend):

- Match style **per language** — TS code follows TS conventions, Python follows Python
- Don't impose 1 language's idioms on another (e.g. JS-style camelCase in Python)
- Cross-language contracts (API response models, shared schemas):
  - Single source of truth (one place defines, others derive)
  - Keep BE response model + FE type + tests in sync
  - Use codegen if available (OpenAPI / Protobuf / Prisma)
- Verify boundary: integration test confirms FE/BE agree, NOT just unit tests on each side

## Common mistakes — DO NOT

- Refactor adjacent code "while I'm here"
- Add config option nobody asked for
- Add validation for scenarios that can't happen
- Comment what the code does
- Patch same bug in 3 places instead of centralizing
- Add new dependency without justification
- Break public API silently
