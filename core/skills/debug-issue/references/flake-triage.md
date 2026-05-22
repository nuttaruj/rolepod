<!-- Load when a test fails intermittently, not every run. -->

A flaky test fails sometimes and passes sometimes on the same code. It is
still a real bug — usually in the test, sometimes in the code. Triage it; do
not retry until it passes.

## First: raise the signal
A 1% flake is not debuggable. Loop the trigger, add concurrency, inject
sleeps, shrink timeouts — push the failure rate above 50% before you debug.

## Flake cause decision tree

| Symptom | Likely cause | Check |
|---------|--------------|-------|
| Fails only when run with other tests | Order dependency / shared state | Run the test alone — does it pass? |
| Fails under load or on a slow machine | Race condition / timing assumption | Look for a fixed `sleep` or an unawaited promise |
| Fails at a time boundary (midnight, month end) | Hard-coded date / timezone | Search the test for `now()` / fixed dates |
| Fails on first run, passes after | Missing setup / warm-cache assumption | Clear the cache / DB and run cold |
| Fails only in CI | Environment difference | Compare env vars, locale, available services |

## Fix at the cause
- Order dependency → isolate state; each test sets up and tears down its own.
- Race → wait on the actual condition, never a fixed `sleep`.
- Time → inject a fixed clock.

Never "fix" a flake by adding a retry — that hides the bug, it does not solve it.
