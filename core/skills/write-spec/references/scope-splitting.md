<!-- Load when a request feels too big for one spec. -->

A spec covers ONE shippable change. A request that hides several is split before drafting — one spec each, sequenced.

## Signals the request is too big
- The goal needs the word "and" to be stated ("import users AND sync them AND notify").
- It touches more than one high-risk surface for unrelated reasons.
- Success criteria split into clusters that could ship on different days.
- Any single slice could be released alone and still deliver value.

## How to split
1. List each independently shippable outcome.
2. Order them by dependency — what must exist before the next slice works.
3. Write a spec for slice 1 only. Name the rest as Non-goals with a "covered by a later spec" note.
4. Surface the slice list to the user and confirm the sequence before drafting.

## Bad vs good

✗ Bad — one mega-spec
> Goal: Build the billing system — plans, checkout, invoices, dunning, refunds.

One spec, five high-risk surfaces, nothing shippable until all five land.

✓ Good — sliced
> Spec 1: Plan selection + checkout (revenue path).
> Spec 2: Invoice generation. Non-goal of spec 1.
> Spec 3: Dunning + refunds. Non-goal of specs 1-2.

Each slice ships and earns alone; risk is reviewed one surface at a time.

## Do not over-split
A change that is genuinely one outcome stays one spec. Splitting a cohesive change into fragments just adds merge overhead. Split by shippable value, not by file count.
