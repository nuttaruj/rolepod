listing: agents
expect: ^1: *rolepod-builder
expect: ^2: *rolepod-builder
expect: ^3: *rolepod-builder
expect: ^4: *rolepod-builder
expect: ^5: *rolepod-qa
expect: ^6: *rolepod-builder
expect: ^7: *rolepod-builder
expect: ^8: *rolepod-builder
---
You are an AI coding agent. The ONLY information you have is the role listing after the `--- LISTING ---` line below (each line: a role name and the description your CLI shows for it). Use no tools; answer from the listing.

Requests (each is a clear single-owner build task):
1. "the /search endpoint p95 latency is 2s and the bundle grew 400KB - find and fix it (one brief: baseline number, change, re-measure)"
2. "add client state and React Query caching to the settings screen component"
3. "update the Dockerfile and the CI pipeline so the release job runs on tags"
4. "write the onboarding FAQ and the in-app error copy"
5. "write end-to-end test cases for the checkout flow"
6. "build the SwiftUI profile screen for the iOS app"
7. "fix the design-token spacing scale and the colour-contrast a11y issues in the CSS"
8. "add the Stripe webhook handler for failed invoice payments"

Question: which ONE role owns each request? Answer with bare role names, one line each, in this exact format:
1: <role>
2: <role>
3: <role>
4: <role>
5: <role>
6: <role>
7: <role>
8: <role>
