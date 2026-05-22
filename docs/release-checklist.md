# Rolepod Release Checklist

Run before tagging a release or merging a hardening pass into `main`. Most steps map to a single `make` target — the checklist is the human-readable wrapper.

## 1. Static checks

```bash
make test-static
```

Verifies:
- `install.sh`, `bootstrap.sh`, `build/render.sh`, `hooks/*.sh` syntax
- `hooks/lib/session_state.py` Python AST
- Plugin manifests: Claude `plugin.json`, Codex `plugin.json` + `hooks.json`, Gemini `gemini-extension.json` + `hooks.json`
- TOML files: generated Codex `agents/*.toml`
- `render-clean`: `core/fragments/` matches generator output, no leaked `{{INCLUDE}}` placeholders
- `lean-surface`: ~70 invariants — Tier 0 = 1 / Tier 1 = 9 / `tier: 3` = 0 / agent preloads Core 10 only / router refs canonical / no hard-dependency language / no `redirect_to_agent` / fallback sections concise / LC_ALL=C reproducible

Fail = release blocked. Fix syntax first.

## 2. Render adapters

```bash
make render
```

Confirms:
- `plugins/rolepod/` — committed Claude plugin tree (18 agents, skills, hooks, manifest)
- `plugins/rolepod-codex/` — committed Codex plugin tree, plus `build/rendered/codex/AGENTS.md`
- `build/rendered/gemini/` — Gemini extension tree (`GEMINI.md`, skills, hooks)
- No leaked `{{INCLUDE: ...}}` placeholders

## 3. Integration (optional but recommended)

```bash
make test-integration
```

Runs 8 structural integration cases (~3-5s total, no live `claude -p` invocations):

| Case | Asserts |
|------|---------|
| `install-parity` | Fresh temp install across Claude global / Claude project / Codex project / Gemini project produces documented artifacts |
| `install-idempotency` | Re-running `install.sh` over an existing install is idempotent — no duplicated hooks, managed blocks, or registry entries |
| `bug-fix-workflow` | `debug-issue` → failing test → minimal fix → `check-work` wiring (skill bodies, router row, no legacy shim dependency) |
| `feature-from-spec` | Define → Plan → Build path: `write-spec` → `write-plan` → `implement-plan` → `check-work` wiring |
| `subagent-review-order` | Two-stage review order (implementer → spec-compliance → code-quality) baked into `implement-plan` body + prompt templates |
| `high-risk-gates` | Auth/billing/migration paths route through `security-engineer` agent + `review-code` adversarial mode |
| `multi-agent-contract` | Cohesion-contract requirement (inside `write-plan`) before 2nd parallel agent spawn |
| `ship-gate` | `finish-work` fires as final ship phase, S+T+F+P gates documented |

Expected output: `pass: 8 / skip: 0 / fail: 0`. Any fail = doctrine drift, block release until reconciled (fix wiring OR update case expectation if intentional).

> **Why no live `claude -p` behavior tests?** Rolepod targets interactive Claude Code sessions (Define → Plan → Build → Verify → Review → Ship multi-turn). `claude -p` is headless single-turn — used for Q&A and one-shot scripts, not for long workflow sessions. Testing routing through `-p` is testing the wrong shape: it cannot exercise phase progression or hook firing. Routing correctness is instead proven structurally by lean-surface (router references Core 10 skill names directly) and by these integration fixtures (skill body content + agent wiring). Real-world workflow behavior is verified by using Rolepod for actual work.

## 4. Honest-doc audit

Manually verify that user-facing docs match runtime behavior:

- README "Rolepod workflow spine" section reflects current Tier 1 list.
- `docs/cli-support.md` runtime table:
  - Claude — Live runtime hooks `✓`
  - **Codex — Live runtime hooks `⚠️ opt-in only` (per `codex features enable plugin_hooks`)**
  - Gemini — Live runtime hooks `✓`
- Project-scope wording: full for Claude, **rules-only** for Codex/Gemini.
- No "auto-fire" claims for Codex hooks.
- The inlined `## Agent protocol` commit-ban + discipline-gate scope statement matches actual hook coverage (Claude-only).

## 5. Local install smoke

```bash
# Fresh install on a temp HOME:
TMP="$(mktemp -d)"
HOME="$TMP/home" ROLEPOD_TARGET="$TMP/.claude" ./install.sh --target=claude
PLUGIN="$TMP/.claude/plugins/rolepod"
ls "$PLUGIN/skills/using-rolepod"            # should exist (Tier 0 router)
ls "$PLUGIN/skills/debug-issue"              # should exist (Core 10 — Build/Debug)
test ! -e "$TMP/.claude/skills/systematic-debugging" # legacy shim removed by migration
ls "$PLUGIN/hooks/lib/session_state.py"      # should exist
ls "$PLUGIN/hooks/always-on-core.md"         # always-on judgment core ships with the plugin
test ! -e "$TMP/.claude/CLAUDE.md"           # pure plugin — install writes no managed block
```

All commands should succeed.

## 6. Git hygiene

- `git status` clean — committed render trees (`plugins/rolepod/`, `plugins/rolepod-codex/`) match `make render` output.
- Tag matches the plugin / extension version (`.claude-plugin/plugin.json`, `gemini-extension.json`).
- Release recorded as a `chore(release): <version>` commit (rolepod keeps no separate CHANGELOG).

## 7. Push

```bash
git push origin main
git push origin <tag>   # if tagging
```

Required CI lanes (Phase 1) green before promotion. Auto-merge OK iff:
- All Phase 1 + path-triggered Phase 2 lanes green
- User explicit approval present for the PR
- No high-risk surface unresolved-blocker

## Fast-loop (working from a hardening branch)

```bash
make test-static && make render && make install && make test-integration
```

Inner loop: lint → render → install locally → run integration fixtures against the freshly installed plugin.

## When something fails

| Failure | First step |
|---|---|
| `bash -n` syntax | Open the file, find unmatched quote / paren / heredoc |
| JSON `json.tool` | `python3 -m json.tool <file>` shows line:col |
| TOML parse | Open file, check for trailing comma / unquoted string |
| `lean-surface` invariant red | Read the specific check that failed — most map directly to a file path + expected pattern |
| `render-clean` red | `make render && git add core/fragments/` — generator output diverged from committed fragment |
| Integration case missing skill | Either Lead drifted (fix `using-rolepod` router refs) or skill body lost a required phrase (sharpen the skill or relax the fixture's regex) |
| `install-parity` fails | `install.sh` regressed; check the temp dir contents at the failing step |
