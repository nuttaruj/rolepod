---
name: performance-optimization
description: Optimize app performance — Core Web Vitals, load time, bundle size, render perf, query latency. Measure first, fix the biggest cost, re-measure.
when_to_use: when performance budgets are missed, regressions appear, or users report slowness
---

# Performance Optimization

Fix biggest cost. Don't optimize what isn't slow. No optimization without before/after numbers.

## When to use

- Core Web Vitals failing (LCP, INP, CLS over budget)
- User slowness reports
- Bundle/page weight grew unexplained
- Slow query/endpoint flagged
- Pre-launch budget check
- Suspected regression after feature ship

## How to apply

1. **Measure first** — baseline + target number
2. **Find biggest cost** — profile, don't guess
3. **Fix one thing** — change → re-measure → keep or revert
4. **Watch regressions elsewhere** — perf wins have footguns
5. **Set budget** — without budget, perf rots

## Core Web Vitals targets

| Metric | Good | Needs work | Poor |
|--------|------|-----------|------|
| LCP | <2.5s | 2.5-4s | >4s |
| INP | <200ms | 200-500ms | >500ms |
| CLS | <0.1 | 0.1-0.25 | >0.25 |
| TTFB | <800ms | 0.8-1.8s | >1.8s |
| FCP | <1.8s | 1.8-3s | >3s |

Real-user data > lab. Lighthouse local ≠ user reality.

## Diagnostic ladder

| Symptom | First check |
|---------|-------------|
| Slow LCP | Critical request chain, image size, render-blocking JS/CSS |
| Slow INP | Long tasks (>50ms), heavy handlers, big re-renders |
| High CLS | Unsized images, late fonts, dynamic above-fold content |
| Slow TTFB | Server time, DB query, cold start, geo distance |
| Big bundle | Source-map-explorer, duplicate deps, unused exports |
| Slow query | EXPLAIN, missing index, N+1, over-fetching |

## Frontend levers (high → low impact)

1. **Defer non-critical JS** — split bundles, lazy routes, dynamic import
2. **Right-size images** — `srcset`, `sizes`, AVIF/WebP, explicit `width/height`
3. **Cache aggressively** — long max-age + content hash
4. **Reduce render-blocking** — async/defer, inline critical CSS
5. **Trim deps** — audit before adding
6. **Memoize hot paths** — only after measuring
7. **Virtualize long lists** — windowing for >100 rows
8. **Preload critical resources** — fonts, hero image, primary fetch

## Backend levers

1. **Cache queries** — read-through or memoize hot endpoints
2. **Index queries** — EXPLAIN before assuming
3. **Batch / paginate** — never unbounded lists
4. **Avoid N+1** — eager-load, DataLoader pattern
5. **Move off request path** — queue, background, pre-compute
6. **Edge** — CDN static, edge functions for latency-sensitive dynamic

## Tools

| Tool | Use for |
|------|---------|
| Lighthouse | Lab CWV + audits |
| Chrome Performance panel | Frame-by-frame, long tasks |
| WebPageTest | Real network, filmstrip, locations |
| RUM | Actual user experience by percentile |
| Bundle analyzer | What's in bundle, why |
| perf_hooks / Server timing | Server hot paths |
| DB EXPLAIN | Query plan reality |

## Common mistakes

- Optimize without measure
- Lab metrics only — RUM tells real story
- Memoize every component (overhead > benefit)
- Over-split code (waterfall of tiny chunks)
- Fix TTFB by hiding behind spinner
- Ignore CLS because dev loads instantly
- Regression check missed — fix LCP, break INP
- One-time fix, no budget → regression returns
- Wrong percentile — p50 fast doesn't help p95

## Performance budget

Per route, enforced in CI.

| Asset | Budget |
|-------|--------|
| HTML | 50 KB |
| CSS | 50 KB |
| JS per route | 150 KB |
| Above-fold images | 200 KB |
| Fonts | 100 KB |
| LCP | 2.5s |
| INP | 200ms |
| CLS | 0.1 |

Starting point — adjust per app, document why.

## Biggest wins by symptom

| Pain | First fix |
|------|-----------|
| Slow first paint | Defer non-critical JS, inline critical CSS |
| Big LCP image | Modern format + `srcset` + preload |
| Janky scroll | Find long task, break up |
| Slow type-ahead | Debounce + virtualize + memoize matcher |
| Slow API | EXPLAIN → index → cache → batch |
| Cold start | Smaller deploy, warm pings, edge runtime |
| Bundle bloat | Audit deps, tree-shake, dynamic imports |
| Layout shift | Explicit dimensions, reserve font space |

## Pre-merge perf check

- [ ] Bundle size delta reported (>10% needs justification)
- [ ] Lighthouse on changed route
- [ ] Long tasks <50ms on critical interactions
- [ ] No new render-blocking resources
- [ ] Images have explicit dimensions
- [ ] No new layout shift
- [ ] CI perf budget green

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Premature optimization is evil" | Knuth's quote is about micro-tuning, not architecture. p95, bundle, CWV = first-class requirements. |
| "Simple change, no skill needed" | DAPLab: 41% of agentic-LLM failures in 'trivial' diffs. |
| "I already know the answer" | Confirmation bias. |
| "Time pressure" | 5 min saved = 50 min debugging. |

Default: run skill.
