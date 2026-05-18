# Rolepod Release Checklist

Run before tagging a release or merging a hardening pass into `main`. Most steps map to a single `make` target — the checklist is the human-readable wrapper.

## 1. Static checks

```bash
make test-static
```

Verifies:
- `install.sh`, `bootstrap.sh`, `build/render.sh`, `hooks/*.sh` syntax
- `hooks/lib/session_state.py`, `tests/workflow-behavior/parse_case.py` Python AST
- Plugin manifests: Claude `plugin.json`, Codex `plugin.json` + `hooks.json`, Gemini `gemini-extension.json` + `hooks.json`
- TOML files: Codex `agents/*.toml`, Gemini `commands/*.toml`

Fail = release blocked. Fix syntax first.

## 2. Render adapters

```bash
make render
```

Confirms:
- `build/rendered/claude/CLAUDE.md`, 18 agents, skill-index, rules
- `build/rendered/codex/AGENTS.md` + plugin tree
- `build/rendered/gemini/GEMINI.md` + extension tree
- No leaked `{{INCLUDE: ...}}` placeholders

## 3. Workflow behavior

```bash
make test-workflow
```

Sends 10 canonical prompts to local Claude CLI. Skips cleanly if CLI absent (acceptable). When CLI present, all 10 cases must pass — they prove the workflow spine routes correctly (vague feature → spec, bug → systematic-debugging, "ship" → pre-merge-gate, etc.).

Fail = router doctrine has drifted. Either fix the prompt routing in `using-rolepod` / skill frontmatter, or update the case expectation if the new behavior is intentional.

## 4. Integration (optional but recommended)

```bash
make test-integration
```

Runs 7 structural integration cases (~3-5s total, no live `claude -p` invocations):

| Case | Asserts |
|------|---------|
| `install-parity` | Fresh temp install across Claude global / Claude project / Codex project / Gemini project produces documented artifacts |
| `bug-fix-workflow` | systematic-debugging → TDD → post-change-verify wiring (skill bodies, router row, compat shims) |
| `feature-from-spec` | Define → Plan → Build path: spec-driven → planning-and-task-breakdown → TDD → post-change-verify wiring |
| `subagent-review-order` | Two-stage review order (implementer → spec-compliance → code-quality) baked into skill body + prompt templates |
| `high-risk-gates` | Auth/billing/migration paths route through security-engineer + reviewer-flow |
| `multi-agent-contract` | parallel-contract-orchestration cohesion-contract requirement before 2nd parallel agent spawn |
| `ship-gate` | pre-merge-gate fires as final ship phase, S+T+F+P gates documented |

Expected output: `pass: 7 / skip: 0 / fail: 0`. Any fail = doctrine drift, block release until reconciled (fix wiring OR update case expectation if intentional).

## 5. Honest-doc audit

Manually verify that user-facing docs match runtime behavior:

- README "Rolepod workflow spine" section reflects current Tier 1 list.
- `docs/cli-support.md` runtime table:
  - Claude — Live runtime hooks `✓`
  - **Codex — Live runtime hooks `⚠️ opt-in only` (per `codex features enable plugin_hooks`)**
  - Gemini — Live runtime hooks `✓`
- Project-scope wording: full for Claude, **rules-only** for Codex/Gemini.
- No "auto-fire" claims for Codex hooks.
- `agent-protocol.md` rule 10 + 11 scope statement matches actual hook coverage (Claude-only).

## 6. Local install smoke

```bash
# Fresh install on a temp HOME:
TMP="$(mktemp -d)"
HOME="$TMP/home" ROLEPOD_TARGET="$TMP/.claude" ./install.sh --target=claude
ls "$TMP/.claude/skills/using-rolepod"      # should exist
ls "$TMP/.claude/skills/systematic-debugging" # should exist
ls "$TMP/.claude/hooks/lib/session_state.py" # should exist
grep using-rolepod "$TMP/.claude/CLAUDE.md"  # should match
```

All commands should succeed.

## 7. Git hygiene

- `git status` clean (no uncommitted CLAUDE.md / AGENTS.md churn from gitnexus volatile fields).
- Tag matches `package.json` / plugin version if applicable.
- CHANGELOG updated.

## 8. Push

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
make test-static && make render && make install && make test-workflow
```

This is the inner loop: lint → render → install locally → run behavior tests against the freshly installed plugin.

## When something fails

| Failure | First step |
|---|---|
| `bash -n` syntax | Open the file, find unmatched quote / paren / heredoc |
| JSON `json.tool` | `python3 -m json.tool <file>` shows line:col |
| TOML parse | Open file, check for trailing comma / unquoted string |
| Workflow case missing skill | Either Lead drifted (fix `using-rolepod`) or skill desc weak (sharpen `description:` + `when_to_use:`) |
| Workflow case forbidden phrase appears | Check skill's "Common Rationalizations" section — likely missing an excuse + reality row |
| `install-parity` fails | `install.sh` regressed; check the temp dir contents at the failing step |
