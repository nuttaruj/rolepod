---
name: source-driven-development
description: Ground every framework, library, schema, or platform-integration decision in official documentation, not training-cached recall. Detect the project's stack and version, fetch current docs, cite inline, flag deprecated patterns. Complements verify-first (reactive) with proactive citation at write time.
when_to_use: writing framework code, integrating an SDK, an API call enters the diff, authoring a plugin/extension/marketplace manifest (plugin.json / marketplace.json / *-extension.json / hooks.json / .mcp.json), targeting any schema-bound config format, any new external-system integration where wrong fields fail silently
---

# Source-Driven Development

Training-cached API knowledge = silent bug factory. Libraries deprecate, signatures change. Every API call cites version-pinned source — at write time.

Adapted from addyosmani/agent-skills (`source-driven-development`). Complements `verify-first` and `claude-api`.

## Iron Law

<EXTREMELY-IMPORTANT>
1. NEVER write a library/framework API call from training recall alone. Fetch version-pinned docs before the line lands in diff.
2. ALWAYS cite source URL or doc path inline (comment or PR body) for non-obvious API usage.
3. Docs vs training memory disagree → trust docs. Training is months-to-years stale.

API knowledge has half-life. Cite or be wrong.
</EXTREMELY-IMPORTANT>

## Red Flags

| Thought | Reality |
|---------|---------|
| "Used this API a hundred times" | May have changed in last minor. Verify. |
| "Docs annoying, recall faster" | Faster to wrong code is not faster. |
| "Basic React hook, no need to cite" | "Basic" hooks change semantics across versions. |
| "WebFetch overkill for one call" | One uncited call begets ten. |
| "Grep codebase for existing example" | Existing example may itself be deprecated. |

## When to use

- Writing code calling framework/library API (React, Next, FastAPI, AWS SDK, Stripe SDK)
- Integrating new SDK/service
- Touching code with API where major version shifted since training (Next 14→15+, React 18→19+, OpenAI v1→v2+, Stripe API bumps)
- Migration between majors
- "Used to work" — silently deprecated API smell
- Any path generated from training recall

Skip: pure language semantics (loops, math), stable stdlib (`os.path`, `Array.map`), project-internal code with no external API.

## How to apply

### Step 1 — DETECT

Read dep manifest to identify stack + version:

| Stack | File | Extract |
|-------|------|---------|
| Node/TS | `package.json` | dep + semver |
| Python | `pyproject.toml` / `requirements.txt` / `Pipfile` | dep + version pin |
| Rust | `Cargo.toml` | crate + version |
| Go | `go.mod` | module + version |
| Ruby | `Gemfile.lock` | gem + version |
| Java/Kotlin | `pom.xml` / `build.gradle` | groupId:artifactId:version |
| PHP | `composer.json` | vendor/package + version |

If `^1.2.3`/`~1.2.3` → resolve via lockfile (`package-lock.json`, `pnpm-lock.yaml`, `poetry.lock`) OR explicitly state assumed version.

### Step 2 — FETCH

WebFetch official docs URL for **detected version**, not "latest" landing.

Good URLs:
- `https://nextjs.org/docs/app` (current major)
- `https://react.dev/reference/react/<hook>`
- `https://docs.stripe.com/api/<resource>`
- `https://docs.aws.amazon.com/sdk-for-javascript/v3/...`

Bad (training-cached):
- Search-engine snippet
- StackOverflow 2019
- "I remember the API does X"
- AI-generated docs cached at training time

Project pins older major → fetch THAT major's docs.

### Step 3 — CITE

Every API call in diff has inline comment OR PR-description link to spec section.

Inline (use sparingly):

```ts
// Source: nextjs.org/docs/app/api-reference/file-conventions/route#response
return NextResponse.json({ ok: true })
```

PR-description (preferred — keeps code clean):

```
## API sources cited
- `app/api/users/route.ts`: Next.js 15 Route Handlers — nextjs.org/docs/app/api-reference/file-conventions/route
- `lib/stripe.ts`: Stripe API 2025-04-30.basil — docs.stripe.com/api/payment_intents/create
```

Per API-surface, not per-line.

### Step 4 — CONFLICT

Existing pattern is deprecated in fetched version:

1. Flag in PR description (don't silently fix unrelated code — scope creep)
2. Confirm with user: "Existing pattern uses deprecated `<api>`. Migrate now, file follow-up, or leave?"
3. Apply user's choice

Silent deprecation fixes blow up review scope.

### Step 5 — HEAD-FIRST CACHE

Same docs page cited multiple times in session → fetch once, reference. Don't re-fetch 5x.

ETag-aware fetch helps but cite is truth, not cache.

## Output format

```
Source citations:
- <api-surface 1>: <official-docs-url>
- <api-surface 2>: <official-docs-url>

Deprecated patterns spotted (not changed in this PR):
- <file:line>: <pattern> → recommended: <new pattern>
```

## Anti-pattern — DO NOT

- Cite search-engine result or blog as "source"
- Cite "latest docs" without specifying version
- Generate API code from training recall, skip fetch
- Fix unrelated deprecated patterns in same PR
- Re-fetch same URL within single task
- Skip manifest read ("I know the project uses Next 15")

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I know this API" | Training is months-to-years stale. Stripe deprecated `Charges.create` for `PaymentIntents`; many models still write the old API. |
| "Docs easy to find later" | Future-you debugging at 2am can't easily reconstruct which version of which page you used. Cite at write time. |
| "Latest docs page is fine" | "Latest" often shows APIs not shipping in pinned major. Pin URL to project version. |
| "Small API call, not worth citing" | Small ones are where silent deprecation hides. |
| "Tests catch wrong API" | Tests catch runtime errors, not "method works but deprecated, removed in v3 next month." |

Default: detect + fetch + cite anyway.
