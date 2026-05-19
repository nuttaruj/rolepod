---
name: new-project-onboarding
description: Compatibility shim — unfamiliar-repo onboarding (stack detection, conventions, entry points) now lives in `manage-context`.
when_to_use: '"first time in repo", "/init", "unfamiliar project", "bootstrap mode", "new project", "learn this codebase"'
tier: 3
redirect_to: manage-context
---

# new-project-onboarding

Compatibility shim. Repo onboarding now lives in **`manage-context`**.

→ Open `core/skills/manage-context/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `manage-context` is not available

Minimum viable fallback:

1. Read `README.md` and `CLAUDE.md` (if present) before any edit
2. Detect stack from `package.json` / `pyproject.toml` / `Cargo.toml` / `Makefile`
3. Read 2-3 representative files to match style and conventions
4. Find the test runner and run a smoke test
5. Identify the entry point and the main module
6. List the high-risk surfaces present in this repo (auth / billing / migration / payments)
7. Do not write a single line of code until the above is complete
