# Rolepod Extension Protocol v1

The shared contract between **rolepod** (parent — workflow + agents + judgment)
and **child plugins** (domain-specific tool suites: `rolepod-uiproof`,
`rolepod-wplab`, `rolepod-dblab`, and future siblings).

Goal: every plugin works **standalone**; combined installs unlock **end-to-end
flows** without forcing the user to install all of them.

---

## Architecture

```
L3  cross-domain orchestration  → rolepod (parent)            [optional]
L2  domain workflow / verbs     → child plugins               [optional]
L1  raw tools (MCP, CLI, etc.)  → child plugin internals      [core]
```

- A user with **rolepod alone** has a phase-based workflow brain that is
  domain-agnostic.
- A user with **a child alone** has a complete domain toolkit.
- A user with **rolepod + N children** has multiplicative power — parent
  routes by phase, children execute domain verbs, parent aggregates evidence.

The parent never ships domain tooling. Children never ship workflow phases.

---

## Detection

Parent writes a marker file at the git worktree root when a session is active.
Children read the file at skill execution time.

### Marker file

```
<git-root>/.rolepod/parent-active
```

Content (UTF-8, trailing newline):

```
v1
```

The string is the **protocol version**. Future protocol revisions will use
`v2`, `v3`, etc. Children should treat unknown versions as `v1`-compatible
when in doubt (graceful degradation), and may emit a one-line warning.

### Lifecycle

- **Create:** parent's SessionStart hook (`session-lifecycle.sh --lock`)
  writes the marker after acquiring the per-worktree session lock.
- **Refresh:** every SessionStart re-touches the file with the current
  protocol version. Multiple concurrent rolepod sessions on the same
  worktree share the same marker.
- **Remove:** parent's Stop hook (`session-lifecycle.sh --unlock`) removes
  the marker **only if no other rolepod sessions hold locks** for the same
  worktree. The marker survives partial unlocks.

### `.gitignore`

Children and users **should** add `.rolepod/` to their repo's `.gitignore`.
The marker is ephemeral session state, and evidence written under
`.rolepod/evidence/` is per-run output. Neither should be committed.

The parent does not modify `.gitignore` automatically — that would be
invasive. The recommendation lives in the README.

---

## Child detection logic

### Bash

```bash
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || GIT_ROOT="$PWD"
PROTOCOL=""
if [ -f "$GIT_ROOT/.rolepod/parent-active" ]; then
  PROTOCOL=$(cat "$GIT_ROOT/.rolepod/parent-active" 2>/dev/null | head -n1 | tr -d '[:space:]')
fi

if [ -n "$PROTOCOL" ]; then
  MODE=with-rolepod
  [ "$PROTOCOL" != "v1" ] && echo "rolepod-protocol: expected v1, got $PROTOCOL — assuming compatible" >&2
else
  MODE=standalone
fi
```

### TypeScript / Node

```ts
import { execSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

export interface ParentState {
  active: boolean;
  protocol: string | null;
}

export function detectRolepodParent(): ParentState {
  let root: string;
  try {
    root = execSync("git rev-parse --show-toplevel", {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
  } catch {
    root = process.cwd();
  }

  const file = join(root, ".rolepod", "parent-active");
  if (!existsSync(file)) return { active: false, protocol: null };

  const protocol = readFileSync(file, "utf8").trim().split(/\r?\n/)[0];
  if (protocol !== "v1") {
    console.warn(
      `rolepod-protocol: expected v1, got "${protocol}" — assuming compatible`,
    );
  }
  return { active: true, protocol };
}
```

---

## Evidence path convention

Child plugins write run artifacts to a path that depends on detected mode:

| Mode | Path |
|---|---|
| standalone | `.rolepod-<plugin>/artifacts/<ts>/` |
| with-parent | `<git-root>/.rolepod/evidence/<ts>-<plugin>-<skill>/` |

Where:
- `<plugin>` = full plugin name (`rolepod-uiproof`, `rolepod-wplab`)
- `<skill>` = skill name (`verify-ui`, `wp-health-check`, …)
- `<ts>` = ISO 8601 timestamp, filesystem-safe (e.g., `2026-05-27T14-30-00`)

The parent's `check-work` skill scans `.rolepod/evidence/` for child output
when aggregating verify evidence. Children should always write a
`manifest.json` (next section) so the aggregator can interpret the run.

---

## manifest.json — evidence schema

Every evidence directory **must** contain a `manifest.json` describing the run.
This is the canonical handoff format. Without it, parent cannot aggregate.

```json
{
  "protocol": "rolepod/v1",
  "plugin": "rolepod-uiproof",
  "skill": "verify-ui",
  "phase": "verify",
  "status": "pass",
  "summary": "Login flow + dashboard render — 12 steps, 0 errors, 0 a11y violations",
  "started_at": "2026-05-27T14:30:00.000Z",
  "finished_at": "2026-05-27T14:30:42.118Z",
  "artifacts": [
    {"type": "screenshot", "path": "./step-12.png"},
    {"type": "har", "path": "./network.har"},
    {"type": "report", "path": "./report.html"}
  ],
  "metadata": {
    "browser": "chromium-119",
    "viewport": "1280x720"
  }
}
```

### Field rules

| Field | Type | Required | Notes |
|---|---|---|---|
| `protocol` | string | yes | `"rolepod/v1"` exact |
| `plugin` | string | yes | full plugin name |
| `skill` | string | yes | name of the skill that produced this evidence |
| `phase` | string | yes | one of: `verify`, `debug`, `build`, `review` |
| `status` | string | yes | one of: `pass`, `fail`, `warn` |
| `summary` | string | yes | single line, ≤120 chars |
| `started_at` | string | yes | ISO 8601 |
| `finished_at` | string | yes | ISO 8601 |
| `artifacts` | array | yes | may be empty; relative paths to files in same dir |
| `metadata` | object | optional | plugin-specific extras |

### Status semantics

- `pass` — all assertions / checks succeeded
- `fail` — one or more assertions / checks failed; surface in check-work as a blocker
- `warn` — soft issues (e.g., moderate a11y violations, network warnings) that
  don't fail the phase but should be flagged in the verify report

Parent's `check-work` aggregates: any `fail` → verify fails. All `pass`/`warn`
→ verify passes with warnings listed.

---

## Phase vocabulary

Child skills declare a `phase` in their manifest. Parent phase skills route
evidence accordingly:

| Phase | Parent skill | Typical child contributions |
|---|---|---|
| `verify` | `check-work` | browser flows, a11y audits, visual diffs, WP health snapshots |
| `debug` | `debug-issue` | browser error traces, WP runtime traces, network failures |
| `build` | `implement-plan` | scaffold output, edit primitives (called by, not aggregated) |
| `review` | `review-code` | a11y reports, change audits, security scans |

Children **do not** declare a `phase` field equal to `define`, `plan`, or
`ship` in v1 — those phases own decisions, not evidence.

---

## Domain detection (parent → child suggestion)

The parent's `using-rolepod` router scans the workspace for signals and
suggests installing a child plugin when the domain matches:

| Signal | Suggested child |
|---|---|
| `wp-config.php` exists at repo root | `rolepod-wplab` |
| `package.json` contains `playwright`, `cypress`, `@playwright/test` | `rolepod-uiproof` |
| `package.json` depends on `react`, `vue`, `svelte`, `next`, `nuxt`, `astro` | `rolepod-uiproof` |
| `alembic.ini` at repo root, or `sqlalchemy` / `psycopg` / `asyncpg` in `requirements.txt` / `pyproject.toml` (non-WordPress DB) | `rolepod-dblab` |
| `.rolepod-uiproof/baselines/` exists | `rolepod-uiproof` already in use |
| `.rolepod-wplab/` exists | `rolepod-wplab` already in use |
| `.rolepod-dblab/` exists | `rolepod-dblab` already in use |
| iOS / Android native project (`*.xcworkspace`, `build.gradle`) | future: `rolepod-mobile` |

This is **suggestion only** — the parent never auto-installs. The user
decides which children to add.

---

## Naming hygiene

Children **must** prefix generic skill names with their plugin identifier or
domain abbreviation. Generic words (`verify`, `debug`, `health`, `audit`)
without a prefix are reserved for parent phase skills.

| OK | Not OK |
|---|---|
| `wp-health-check`, `wp-diagnose` | `health-check`, `diagnose` |
| `verify-ui`, `audit-a11y` (unique enough to stand alone) | `verify`, `audit` |

When in doubt, prefix.

---

## Per-CLI support

The marker mechanism is written by the parent's SessionStart / Stop hooks. In v2.7 the marker is wired through **Claude Code only** (`hooks/session-lifecycle.sh`). The Codex / Gemini / Cursor adapters do not yet wire the marker because their plugin event models differ (no Stop event in Codex; Cursor and Gemini sessionStart hooks are reserved for context injection in v2.7).

| CLI | Protocol v1 active |
|---|---|
| Claude Code | ✓ marker written via `session-lifecycle.sh` |
| Codex | ✗ — children fall back to standalone |
| Gemini | ✗ — children fall back to standalone |
| Cursor | ✗ — children fall back to standalone |

Cross-CLI marker support will land in a future protocol revision once the adapter session-end APIs allow safe marker removal. Standalone behavior on the other CLIs is unaffected.

## Versioning

| Component | Min version for protocol v1 |
|---|---|
| `rolepod` (parent) | 2.7.0 |
| `rolepod-uiproof` | 0.6.0 |
| `rolepod-wplab` | 1.9.0 |
| `rolepod-dblab` | 0.1.0 |

Lower versions cannot participate in combined mode — they will fall back to
their own pre-protocol behavior, which is functionally standalone. No
breakage; just no aggregation.

When the protocol evolves to v2, the parent will continue writing `v1` to
the marker file for backward compatibility, until all known children
support v2. Children should accept any version string and warn on
mismatch rather than refuse.

---

## Standalone-first guarantee

Every plugin in the rolepod family **must** work without any of its siblings
installed. The protocol is a value-add for combined installs, never a
required dependency.

If a child plugin's skill cannot detect the parent, it must run its full
standalone behavior. No silent failures, no degraded UX, no nag messages.

The parent itself works without any child — its workflow phases handle any
project type via generic verbs.

---

## What this protocol does NOT do

- **Dynamic capabilities registration** — no `.claude-plugin/capabilities.json`
  in v1. If we need this later, v2 will add it.
- **Protocol version negotiation** — v1 only. Children warn on mismatch but
  don't refuse to run.
- **Cross-child handoff inside a single run** — uiproof and wplab don't
  call each other directly; parent orchestrates both separately and merges
  evidence at `check-work`.
- **Hooks in children** — children should not install their own SessionStart
  hooks for protocol purposes. Detection is read-on-demand at skill execution.

---

## Compatibility matrix

| Install combo | Mode | Behavior |
|---|---|---|
| rolepod alone | n/a | workflow + agents for any project |
| uiproof alone | standalone | 5 browser tools, evidence in `.rolepod-uiproof/artifacts/` |
| wplab alone | standalone | 14 WP skills + 82 MCP tools, full flow |
| rolepod + uiproof | combined | uiproof evidence routes to `.rolepod/evidence/`, aggregated by `check-work` |
| rolepod + wplab | combined | wplab phase-flavored skills narrow to tool role, evidence aggregated |
| uiproof + wplab (no parent) | standalone × 2 | each runs alone; no aggregation across them |
| all three | combined × 2 | full WP dev flow with browser evidence at every phase |

---

## File reference

| Concern | File |
|---|---|
| Marker write/remove | `hooks/session-lifecycle.sh` |
| Domain detection | `core/skills/using-rolepod/SKILL.md` |
| Evidence aggregation | `core/skills/check-work/SKILL.md` |
| Child routing (debug) | `core/skills/debug-issue/SKILL.md` |
| Child routing (build) | `core/skills/implement-plan/SKILL.md` |
| Child handoff briefs | `brief/handoff-uiproof-v0.6.md`, `brief/handoff-wplab-v1.9.md` |
