---
name: source-driven-development
description: Ground every framework or library decision in official documentation, not training-cached recall. Detect the project's stack and version, fetch current docs, cite inline, flag deprecated patterns. Complements verify-first (reactive) with proactive citation at write time. Use when writing framework code, integrating an SDK, or whenever an API call enters the diff.
---

# Source-Driven Development

Training-cached API knowledge is a silent bug factory. Libraries deprecate, signatures change, "best practices" rotate. This skill makes every API call cite the version-pinned source it was derived from — at write time, not after a bug.

Adapted from addyosmani/agent-skills (`source-driven-development`). Complements `verify-first` (verify before claiming) and `claude-api` (Claude SDK specifics) with the proactive write-time citation.

## When to use

- Writing code that calls a framework / library API (React, Next, FastAPI, Django, AWS SDK, Stripe SDK, etc.)
- Integrating a new SDK / service
- Touching code that uses an API where the major version has shifted since training (Next 14→15+, React 18→19+, OpenAI v1→v2+, Stripe API version bumps)
- Migration from one major version to another
- User reports "this used to work" — pattern smells like silently-deprecated API
- Any time a code path is generated from training recall instead of read

Skip when: pure language semantics (loops, lists, math), stable stdlib (Python `os.path`, JS `Array.map`), project-internal code with no external API surface.

## How to apply

### Step 1 — DETECT

Before writing API code, read dep manifest to identify stack + version:

| Stack | File | What to extract |
|-------|------|-----------------|
| Node / TS | `package.json` | dep name + semver |
| Python | `pyproject.toml` / `requirements.txt` / `Pipfile` | dep name + version pin |
| Rust | `Cargo.toml` | crate + version |
| Go | `go.mod` | module + version |
| Ruby | `Gemfile.lock` | gem + version |
| Java/Kotlin | `pom.xml` / `build.gradle` | groupId:artifactId:version |
| PHP | `composer.json` | vendor/package + version |

If version is `^1.2.3` / `~1.2.3` / `>=1.2.3` → resolve to actual installed version via lockfile (`package-lock.json`, `pnpm-lock.yaml`, `poetry.lock`, etc.) OR explicitly state the version assumed.

### Step 2 — FETCH

WebFetch the official docs URL **for the detected version**, not the "latest" landing page.

Good URL patterns:
- `https://nextjs.org/docs/app` (current major's app dir)
- `https://react.dev/reference/react/<hook>`
- `https://docs.stripe.com/api/<resource>` (Stripe pins API version per integration)
- `https://docs.aws.amazon.com/sdk-for-javascript/v3/...` (v3 explicit)

Bad URL patterns (training-cached):
- Search-engine snippet
- StackOverflow answer from 2019
- "I remember the API does X"
- AI-generated docs site (e.g. devdocs cached at training time)

If the project pins an older major, fetch THAT major's docs. Current docs may show APIs that don't exist yet in the project's version.

### Step 3 — CITE

Every API call introduced in the diff has an inline comment OR PR-description link to the spec section it's derived from.

Inline pattern (use sparingly — only when API choice is non-obvious):

```ts
// Source: nextjs.org/docs/app/api-reference/file-conventions/route#response
return NextResponse.json({ ok: true })
```

PR-description pattern (preferred — keeps code clean):

```
## API sources cited
- `app/api/users/route.ts`: Next.js 15 Route Handlers — nextjs.org/docs/app/api-reference/file-conventions/route
- `lib/stripe.ts`: Stripe API 2025-04-30.basil — docs.stripe.com/api/payment_intents/create
```

Citation is per-API-surface, not per-line. One link covers all calls into the same API in the same file.

### Step 4 — CONFLICT

Read the surrounding code that ALREADY uses this API. If the existing pattern is deprecated in the version you fetched:

1. Flag it in the PR description (don't silently fix unrelated code — that's scope creep)
2. Confirm with user: "Existing pattern in `<file>` uses deprecated `<api>`. Migrate now, file follow-up, or leave alone?"
3. Apply user's choice; never just touch unrelated deprecated calls in the same PR

Why: silent deprecation fixes blow up review scope and bury the actual change.

### Step 5 — HEAD-FIRST CACHE

If the same docs page will be cited multiple times in one session, fetch once + reference. Don't re-fetch the same URL 5 times.

If the harness has ETag-aware fetch (Anthropic Skills' default WebFetch has light caching), let it do its job — but don't rely on it for correctness. The cite is the truth, not the cache.

## Common Rationalizations

When you're tempted to skip this skill, watch for these excuses:

| Excuse | Reality |
|--------|---------|
| "I know this API, I use it all the time" | Training data is months-to-years stale. Stripe deprecated `Charges.create` for `PaymentIntents`; many models still write the old API. Verify or be wrong. |
| "The docs are easy to find later if needed" | Future-you debugging at 2am can't easily reconstruct WHICH version of WHICH page you derived from. Cite at write time. |
| "Latest docs page should be fine" | "Latest" docs often show APIs that don't ship in the project's pinned major. Pin the docs URL to the project's version. |
| "It's a small API call, not worth citing" | The small ones are where silent deprecation hides. Big migrations get reviewed; small calls don't. |
| "Tests will catch a wrong API" | Tests catch API errors at runtime; they don't catch "this method works but is deprecated and removed in v3 next month." |

Default response when rationalizing: detect + fetch + cite anyway. Cost = one WebFetch + one comment line. Cost of skipping = a class of bugs that surface during migration, not during the original PR.

## Output format

End-of-task report includes:

```
Source citations:
- <api-surface 1>: <official-docs-url>
- <api-surface 2>: <official-docs-url>

Deprecated patterns spotted (not changed in this PR):
- <file:line>: <pattern> → recommended replacement: <new pattern>
```

## Anti-pattern — DO NOT

- Cite a search-engine result or a blog post as "the source"
- Cite "the latest docs" without specifying version
- Generate API code from training recall and skip the fetch
- Fix unrelated deprecated patterns in the same PR (file follow-up instead)
- Re-fetch the same URL within a single task
- Skip the manifest read ("I know the project uses Next 15") — read it, don't assume
