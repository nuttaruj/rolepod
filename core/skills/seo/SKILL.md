---
name: seo
description: Compatibility shim — SEO work now flows through `implement-plan` with the `growth-marketer` agent adding depth when available.
when_to_use: when planning content, before launching new pages, when traffic plateaus or drops, or when migrating a site
tier: 3
redirect_to: implement-plan
---

# seo

Compatibility shim. SEO implementation work now lives in **`implement-plan`**; the `growth-marketer` agent adds depth when installed.

→ Open `core/skills/implement-plan/SKILL.md` and follow that instead. Brief `growth-marketer` if available.

This shim preserves the legacy trigger phrase during the migration release.

## If `implement-plan` is not available

Minimum viable fallback:

1. Unique title + meta description per page; canonical URL set
2. Internal linking — each page reachable from the home / hub in ≤ 3 hops
3. Crawl budget: sitemap.xml current, robots.txt allows the target paths
4. Structured data (JSON-LD) where the page is product / article / FAQ / event
5. Core Web Vitals: LCP, INP, CLS within target before launch
6. Site migration → 301 every old URL; do not break inbound link equity
7. Measure: GSC impressions + clicks, not just rank
