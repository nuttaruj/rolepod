---
name: performance-optimization
description: Optimize app performance — Core Web Vitals, load time, bundle size, render perf, query latency. Use when performance budgets are missed, regressions appear, or users report slowness. Measure first, fix the biggest cost, re-measure.
---

# Performance Optimization

Performance is a cost problem. Fix the biggest cost. Don't optimize what isn't slow. Don't ship optimization without before/after numbers.

## When to use

- Core Web Vitals failing (LCP, INP, CLS over budget)
- User reports of slowness
- Page weight or bundle size grew without explanation
- Slow query / endpoint flagged
- Pre-launch perf budget check
- Suspected regression after a feature ship

## How to apply

1. **Measure first** — never optimize without a baseline. State the number you're trying to move.
2. **Find the biggest cost** — profiling beats guessing. The thing you suspect is slow is rarely the thing that's slowest.
3. **Fix one thing** — change → re-measure → keep or revert.
4. **Watch for regressions elsewhere** — perf wins often come with footguns.
5. **Set a budget** — without a budget, perf rots.

## Core Web Vitals targets

| Metric | Good | Needs work | Poor |
|--------|------|-----------|------|
| LCP (largest contentful paint) | <2.5s | 2.5-4s | >4s |
| INP (interaction to next paint) | <200ms | 200-500ms | >500ms |
| CLS (cumulative layout shift) | <0.1 | 0.1-0.25 | >0.25 |
| TTFB (time to first byte) | <800ms | 0.8-1.8s | >1.8s |
| FCP (first contentful paint) | <1.8s | 1.8-3s | >3s |

Real-user data > lab data. Lighthouse on your machine ≠ what users see.

## Diagnostic ladder

| Symptom | First check |
|---------|-------------|
| Slow LCP | Critical request chain, image size, render-blocking JS/CSS |
| Slow INP | Long tasks (>50ms), heavy event handlers, big re-renders |
| High CLS | Unsized images, late-loading fonts, dynamic content above fold |
| Slow TTFB | Server time, DB query, cold start, geo distance |
| Big bundle | Source-map-explorer, duplicate deps, unused exports |
| Slow query | EXPLAIN, missing index, N+1, over-fetching |

## Frontend levers (high to low impact)

1. **Defer non-critical JS** — split bundles, lazy-load routes, dynamic import
2. **Right-size images** — `srcset`, `sizes`, modern formats (AVIF/WebP), explicit `width/height`
3. **Cache aggressively** — long max-age + content hash on static assets
4. **Reduce render-blocking** — async/defer scripts, inline critical CSS
5. **Trim dependencies** — every package has a cost, audit before adding
6. **Memoize hot paths** — but only after measuring; over-memo is its own cost
7. **Virtualize long lists** — windowing for >100 rows
8. **Preload critical resources** — fonts, hero image, primary fetch

## Backend levers

1. **Cache queries** — read-through cache or memoization on hot endpoints
2. **Index queries** — EXPLAIN before assuming
3. **Batch / paginate** — never return unbounded lists
4. **Avoid N+1** — eager-load relations, use DataLoader pattern
5. **Move work off the request path** — queue, background job, pre-compute
6. **Geographic edge** — CDN for static, edge functions for dynamic if latency matters

## Measurement tools

| Tool | Use for |
|------|---------|
| Lighthouse | Lab Core Web Vitals + audit categories |
| Chrome Performance panel | Frame-by-frame analysis, long tasks, scripting |
| WebPageTest | Real-network conditions, filmstrip, multiple locations |
| Real-user monitoring (RUM) | Actual user experience by percentile |
| Bundle analyzer | What's in the bundle and why |
| `perf_hooks` / Server timing | Server-side hot path cost |
| Database EXPLAIN | Query plan reality check |

## Common mistakes

- Optimizing without measuring (premature optimization)
- Lab metrics only — RUM tells the real story
- Memoizing every component (overhead > benefit)
- Code-splitting too aggressively (waterfall of tiny chunks)
- Fixing TTFB by hiding it behind a spinner
- Ignoring CLS because it doesn't show in dev (fonts and images load instantly locally)
- Regression check missed — fix LCP, break INP
- One-time fix, no budget set — regression returns next quarter
- Optimizing the wrong percentile — p50 fast doesn't help the p95

## Performance budget

Set per route. Enforce in CI.

| Asset | Budget |
|-------|--------|
| HTML | 50 KB |
| CSS | 50 KB |
| JS (per route) | 150 KB |
| Images (above fold) | 200 KB total |
| Fonts | 100 KB |
| LCP | 2.5s |
| INP | 200ms |
| CLS | 0.1 |

Numbers are a starting point — adjust per app, but document why.

## Quick reference — biggest wins by symptom

| Pain | First fix to try |
|------|------------------|
| Slow first paint | Defer non-critical JS, inline critical CSS |
| Big LCP image | Modern format + `srcset` + preload |
| Janky scroll | Profile, find long task, break it up |
| Slow type-ahead | Debounce + virtualize + memoize match function |
| Slow API | EXPLAIN → index, then cache, then batch |
| Cold start | Smaller deploy, warm pings, edge runtime |
| Bundle bloat | Audit deps, tree-shake, dynamic imports |
| Layout shift | Set `width/height` on images, reserve font space |

## Pre-merge perf check

- [ ] Bundle size delta reported (no >10% growth without justification)
- [ ] Lighthouse run on the changed route
- [ ] Long tasks <50ms on critical interactions
- [ ] No new render-blocking resources
- [ ] Images have explicit dimensions
- [ ] No new layout shift
- [ ] CI perf budget green
