listing: all
expect: ^1: *debug-issue
expect: ^2: *orchestrating-plans
expect: ^3: *check-work
expect: ^4: *convening-code-review
expect: ^5: *finish-work
expect: ^6: *write-plan
expect: ^7: *coordinating-parallel-tracks
expect: ^8: *tdd-flow
---
You are an AI coding agent. The ONLY skill information you have is the skill listing after the `--- LISTING ---` line below (each line: a skill name and the description your CLI shows for it). `using-rolepod` has already routed every request below as a commission. Use no tools; answer from the listing.

Requests:
1. "the checkout test started failing after yesterday's merge — fix it"
2. "execute the approved plan docs/rolepod/plans/billing-export-2026-10-01.md"
3. "does the CSV export actually work now? show me proof before we call it done"
4. "review this diff before I merge it"
5. "everything is verified and reviewed — merge the branch to main"
6. "ช่วยเขียนแผนงานจาก spec ที่อนุมัติแล้วให้หน่อย"
7. "the plan's Parallel layout names tracks A and B — run them"
8. "do this test-first: orders over 100 get a 10% discount"

Question: which ONE skill fits each request best? Answer with bare skill names, one line each, in this exact format:
1: <skill>
2: <skill>
3: <skill>
4: <skill>
5: <skill>
6: <skill>
7: <skill>
8: <skill>
