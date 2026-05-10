---
name: seo
description: Audit and improve SEO across technical, on-page, structured-data, and content layers. Use when planning content, before launching new pages, when traffic plateaus or drops, or when migrating a site.
---

# SEO

Search rankings come from a small set of things done well, repeatedly: pages that load fast, content that matches intent, structure search engines can read, and links from sites that mean something. Most "SEO problems" are one of those four broken at scale.

## When to use

- New site or new section about to launch
- Traffic plateau or drop you can't explain
- Migrating domain, framework, or URL structure
- Adding a content engine (blog, docs, knowledge base)
- Competitor outranks you on terms you should own
- Quarterly hygiene audit

## The four layers

Diagnose top-down. Don't optimize anchor text on a page that's blocked by robots.txt.

```
1. Technical    → Can the page be crawled, rendered, indexed?
2. On-page      → Does the content match the query intent?
3. Structured   → Can engines understand entities and relationships?
4. Authority    → Do other sites credibly link to it?
```

## 1. Technical SEO

The non-negotiable floor. If this layer is broken, nothing else matters.

| Check | Pass condition |
|-------|----------------|
| robots.txt | Doesn't accidentally block important paths |
| Sitemap | Submitted, current, only canonical URLs, returns 200 |
| Canonical tags | Every indexable page has one, points to itself or correct canonical |
| HTTPS | Whole site, no mixed content |
| Mobile-friendly | Passes responsive design + viewport tag |
| Core Web Vitals | LCP < 2.5s, INP < 200ms, CLS < 0.1 (75th percentile, real users) |
| Crawl depth | Important pages within 3 clicks from home |
| 4xx / 5xx | None on indexed URLs; 404s have a real 404 status, not 200 |
| Redirects | 301 for permanent; chains kept to 1 hop |
| Render | Critical content present in initial HTML or hydrated reliably |
| hreflang (if multi-locale) | Correct language/region codes, reciprocal |
| Structured logs / GSC | Enabled, monitored, errors triaged weekly |

Most common technical mistakes:

- Single-page apps where Googlebot sees an empty shell because content waits for client-side fetch
- `noindex` left on staging that got copy-pasted to prod
- Pagination handled with infinite scroll only — content beyond the first batch is invisible
- Faceted navigation creating millions of low-value URLs (canonical or `noindex` them)
- Slow LCP from one giant hero image not served in a modern format

## 2. On-page SEO

Match the page to the query. The query has an intent — informational, navigational, commercial, transactional. Wrong intent ranks badly even with perfect technicals.

| Element | What good looks like |
|---------|---------------------|
| Title tag | 50-60 chars, includes primary term, written for humans first |
| Meta description | 140-160 chars, compelling, sets expectation; treat as ad copy |
| H1 | One per page, clearly states what the page is about |
| H2/H3 structure | Outlines the content; not styled-down body text |
| URL | Short, lowercase, hyphenated, descriptive — `/blog/seo-audit` not `/blog/p?id=4521` |
| Body content | Answers the actual query, not the query you wish people asked |
| Internal links | From related pages, with descriptive anchor text |
| Images | Alt text describing the image (not stuffed), `loading="lazy"`, modern format |
| First 100 words | Establish what the page is about — both for users and engines |

Intent matching:

- "How to X" → tutorial / guide; not a pricing page
- "Best X" → comparison / list; not a sales page
- "X vs Y" → side-by-side comparison
- "Buy X" → product / category page
- "X login" → navigational; usually you can't outrank the official site

Skip schema on the wrong intent and you'll waste effort.

## 3. Structured data

Schema.org markup helps engines understand entities and earn rich results. JSON-LD is the recommended format.

High-value types:

- `Article` / `BlogPosting` — for editorial content
- `Product` + `Offer` + `AggregateRating` — for ecommerce
- `FAQPage` — for FAQ sections (only if the FAQ is genuinely on-page and visible)
- `HowTo` — for step-by-step guides
- `BreadcrumbList` — for navigation
- `Organization` / `LocalBusiness` — for site-wide entity signal
- `SoftwareApplication` — for SaaS / app pages

Validation: every change goes through Google's Rich Results Test before merging. Invalid schema is sometimes worse than no schema.

Don't:

- Mark up content that isn't visible to users (cloaking)
- Add `Review` schema for self-reviews — manual penalty risk
- Stuff every page with every type — relevance > coverage

## 4. Authority and content strategy

Rankings on competitive terms require trust signals. Trust comes from useful content other people reference.

- **Topic clusters** — pillar page on a broad topic, supporting pages on sub-topics, internal links between them. Demonstrates depth.
- **Original research / data** — the most-linked-to content type in most niches.
- **Subject-matter authorship** — author bylines, real bios, expertise visible. Especially important in YMYL categories (finance, health, legal).
- **Earned links** > paid links. Don't buy links. Don't trade links at scale.
- **Brand search** — branded queries are a strong trust signal; building brand drives SEO indirectly.
- **Content freshness** — refresh top pages periodically. Stale pages on time-sensitive topics decay.

## Audit workflow

1. **Crawl the site** with a real crawler (not just GSC). See what Google sees.
2. **Cross-reference with GSC**: indexed vs. submitted, impressions, query mismatch.
3. **Sort issues by impact** — site-wide technical block beats one-page on-page miss.
4. **Pick the top 5 fixes** — don't write a 100-page audit nobody acts on.
5. **Ship in priority order, measure each.**
6. **Re-audit quarterly.**

## Migration checklist

Site migration is the single biggest SEO risk. Ship one of these checks broken and you can lose months of traffic.

- [ ] URL map: every old URL has a defined destination (301 or kept)
- [ ] Redirects ship at the moment the new URLs go live
- [ ] No redirect chains (A → B → C); collapse to A → C
- [ ] Canonicals point to new URLs, not old
- [ ] Sitemap submitted with new URLs
- [ ] Internal links updated to new URLs (don't rely on redirects forever)
- [ ] robots.txt re-checked on new domain / framework
- [ ] hreflang re-validated if multi-locale
- [ ] GSC properties added for new domain / protocol
- [ ] Monitor 404s for the first month, fix the ones with traffic

## Common mistakes

- Optimizing for keywords nobody searches
- Optimizing for keywords with intent the page doesn't match
- "Just write more blog posts" without a topic cluster strategy
- Ignoring search intent because the keyword volume looks great
- Keyword stuffing in title / H1 / alt text
- Removing old pages instead of redirecting them
- Letting low-quality pages ("hello world" / "coming soon") accumulate — they dilute site quality
- Treating SEO as a one-time launch task instead of ongoing maintenance
- Ranking obsessively on a vanity term while losing real revenue queries
- Blocking JS / CSS in robots.txt — engines need to render, not just crawl HTML

## Quick reference — diagnostic

| Symptom | First place to look |
|---------|--------------------|
| Page not indexed | robots.txt, noindex, canonical pointing elsewhere |
| Indexed but no impressions | Title / content mismatch with target query |
| Impressions but no clicks | Title + meta description |
| Clicks but high bounce | Intent mismatch, slow page |
| Sudden traffic drop | Algorithm update, technical regression, manual action |
| Steady decline over months | Content freshness, competitor outranking |
| Migration drop | Redirect map gap, canonicals not updated |

## Output format — audit deliverable

```
Scope: [pages / sections audited]
Top issues (by impact):
  1. [Issue] — [scale] — [suggested fix] — [effort]
  2. ...
Quick wins (this week): [list]
Strategic fixes (next quarter): [list]
Tracking: [metric, baseline, target]
```
