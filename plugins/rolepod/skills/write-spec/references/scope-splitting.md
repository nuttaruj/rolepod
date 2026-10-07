<!-- Load when a request feels too big for one spec. -->

A spec covers ONE shippable change. A request that hides several is split before drafting — one spec each, sequenced.

## Signals the request is too big
- The goal needs the word "and" to be stated ("import users AND sync them AND notify").
- Open decisions block listing the outcomes → `chart-work.md` (chart the decisions, then split).
- It touches more than one high-risk surface for unrelated reasons.
- Success criteria split into clusters that could ship on different days.
- Any single slice could be released alone and still deliver value.
- The request arrives as phases (a phase table, a numbered rollout).

## How to split
1. List each independently shippable outcome.
2. Order them by dependency — what must exist before the next slice works.
3. Write every slice the request commissions in this sitting, from one discovery, approved once as a set with its map (`chart-work.md` Phases); a slice that waits on what an earlier slice's build finds stays a Non-goal.
4. Confirm the slice list and build order with the user in Discovery, before drafting.

## Bad vs good

✗ Bad — one mega-spec
> Goal: Build the billing system — plans, checkout, invoices, dunning, refunds.

One spec, five high-risk surfaces, nothing shippable until all five land.

✓ Good — sliced
> Spec 1: Plan selection + checkout (revenue path).
> Spec 2: Invoice generation. Non-goal of spec 1.
> Spec 3: Dunning + refunds. Non-goal of specs 1-2.

## Do not over-split
A change that is genuinely one outcome stays one spec. Split by shippable value, not by file count.
