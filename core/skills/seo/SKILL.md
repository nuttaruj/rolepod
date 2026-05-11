---
name: seo
description: Audit and improve SEO across technical, on-page, structured-data, and content layers. Use when planning content, before launching new pages, when traffic plateaus or drops, or when migrating a site.
---

# SEO

Rankings come from four things done well: fast pages, intent-matched content, structure engines can read, links from sites that mean something. Most "SEO problems" = one of those four broken at scale.

## When to use

- New site/section launching
- Traffic plateau or drop
- Migrating domain/framework/URLs
- Adding content engine
- Competitor outranks you on terms you should own
- Quarterly hygiene audit

## The four layers — diagnose top-down

```
1. Technical    → Can the page be crawled, rendered, indexed?
2. On-page      → Does content match query intent?
3. Structured   → Can engines understand entities?
4. Authority    → Do credible sites link to it?
```

Don't optimize anchor text on a page blocked by robots.txt.

## 1. Technical SEO — non-negotiable floor

| Check | Pass condition |
|-------|----------------|
| robots.txt | Doesn't block important paths |
| Sitemap | Submitted, current, canonical URLs, 200 |
| Canonical tags | Every indexable page has one, points correctly |
| HTTPS | Whole site, no mixed content |
| Mobile | Responsive + viewport tag |
| Core Web Vitals | LCP <2.5s, INP <200ms, CLS <0.1 (75th pctile real users) |
| Crawl depth | Important pages ≤3 clicks from home |
| 4xx/5xx | None on indexed URLs; 404s return real 404 |
| Redirects | 301 permanent; chains ≤1 hop |
| Render | Critical content in initial HTML or reliable hydration |
| hreflang | Correct codes, reciprocal (multi-locale) |
| GSC | Enabled, errors triaged weekly |

Most common mistakes:
- SPAs where Googlebot sees empty shell waiting for client fetch
- `noindex` left from staging
- Infinite-scroll-only pagination (content beyond first batch invisible)
- Faceted nav creating millions of low-value URLs
- Slow LCP from one giant hero image

## 2. On-page SEO — match the intent

Intent: informational / navigational / commercial / transactional. Wrong intent ranks badly even with perfect technicals.

| Element | What good looks like |
|---------|---------------------|
| Title | 50-60 chars, primary term, human-first |
| Meta description | 140-160 chars, ad copy |
| H1 | One, states page topic clearly |
| H2/H3 | Outline, not styled body |
| URL | Short, lowercase, hyphenated, descriptive |
| Body | Answers the actual query |
| Internal links | From related pages, descriptive anchor |
| Images | Alt text, lazy load, modern format |
| First 100 words | Establish topic |

Intent matching:
- "How to X" → tutorial, not pricing
- "Best X" → comparison, not sales
- "X vs Y" → side-by-side
- "Buy X" → product/category
- "X login" → navigational (can't outrank official site)

## 3. Structured data

Schema.org as JSON-LD. High-value types: `Article`/`BlogPosting`, `Product`+`Offer`+`AggregateRating`, `FAQPage` (only if visible on-page), `HowTo`, `BreadcrumbList`, `Organization`/`LocalBusiness`, `SoftwareApplication`.

Validate every change with Google's Rich Results Test. Invalid schema worse than none.

Don't: mark up hidden content (cloaking), self-review markup, stuff every page with every type.

## 4. Authority and content

- **Topic clusters** — pillar page + sub-topic pages + internal links
- **Original research/data** — most-linked content type
- **Authorship** — bylines + real bios, esp. YMYL (finance/health/legal)
- **Earned > paid links.** Don't buy/trade at scale.
- **Brand search** — branded queries = strong trust signal
- **Freshness** — refresh top pages periodically

## Audit workflow

1. Crawl site with real crawler (not just GSC)
2. Cross-reference with GSC (indexed vs submitted, query mismatch)
3. Sort by impact — site-wide technical beats one-page miss
4. Pick top 5 fixes
5. Ship in priority order, measure each
6. Re-audit quarterly

## Migration checklist

Biggest SEO risk. One broken check = months of traffic lost.

- [ ] URL map: every old URL → defined destination
- [ ] Redirects ship when new URLs go live
- [ ] No redirect chains
- [ ] Canonicals point to new URLs
- [ ] Sitemap submitted with new URLs
- [ ] Internal links updated (don't rely on redirects forever)
- [ ] robots.txt re-checked
- [ ] hreflang re-validated
- [ ] GSC properties added
- [ ] Monitor 404s first month, fix ones with traffic

## Common mistakes

- Optimizing for keywords nobody searches
- Optimizing for keywords with intent that doesn't match
- "Write more blog posts" without cluster strategy
- Keyword stuffing
- Removing old pages instead of redirecting
- Letting low-quality pages accumulate
- Treating SEO as one-time launch task
- Blocking JS/CSS in robots.txt

## Quick reference — diagnostic

| Symptom | First place to look |
|---------|---------------------|
| Not indexed | robots.txt, noindex, canonical |
| Indexed, no impressions | Title/content mismatch with target query |
| Impressions, no clicks | Title + meta description |
| Clicks, high bounce | Intent mismatch, slow page |
| Sudden drop | Algorithm update, technical regression, manual action |
| Steady decline | Freshness, competitor |
| Migration drop | Redirect map gap, canonicals |

## Output format

```
Scope: [pages/sections audited]
Top issues (by impact):
  1. [Issue] — [scale] — [fix] — [effort]
Quick wins (this week): [list]
Strategic (next quarter): [list]
Tracking: [metric, baseline, target]
```

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Google figures it out from content" | Crawlability + structured data + CWV are explicit ranking inputs. |
| "Simple change, doesn't need this" | 41% of agentic-LLM failures hide in trivial diffs (DAPLab). |
| "Time pressure, skip once" | Tech debt compounds. |

Default: run anyway.
