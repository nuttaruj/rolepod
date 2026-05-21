# Rolepod release gate. One command per test phase.
#
# Usage:
#   make test-static       — fast (<5s) — syntax + JSON/TOML parse + render-clean + lean-surface
#   make test-integration  — slow local tests (skips per-case if deps missing)
#   make test              — test-static (release gate)
#   make test-all          — test-static + test-integration
#
# Rolepod does NOT ship `claude -p` headless behavior tests. The framework
# targets interactive Claude Code sessions (Define → Plan → Build → Verify →
# Review → Ship), which `-p` single-turn mode does not exercise. Routing
# correctness is proven structurally by lean-surface + integration fixtures.
#
# Each command exits 0 on pass/skip and non-zero only on hard fail.

.PHONY: test test-static test-integration test-all render install help

help:
	@echo "Rolepod test commands:"
	@echo "  make test-static                  — bash syntax + JSON/TOML parse + render-clean + lean-surface"
	@echo "  make test-integration             — structural integration fixtures (slow, local)"
	@echo "  make test                         — test-static (release gate)"
	@echo "  make test-all                     — test-static + test-integration"
	@echo ""
	@echo "  make render                       — render adapters to build/rendered/"
	@echo "  make install                      — install --target=claude --force into ~/.claude/"

test-static:
	@echo "── test-static ──"
	@bash -n install.sh && echo "  ✓ install.sh syntax"
	@bash -n bootstrap.sh && echo "  ✓ bootstrap.sh syntax"
	@bash -n build/render.sh && echo "  ✓ render.sh syntax"
	@for f in hooks/*.sh; do bash -n "$$f" || { echo "  ✗ $$f"; exit 1; }; done
	@echo "  ✓ hooks/*.sh syntax"
	@for f in adapters/codex/plugins/rolepod/hooks/*.sh; do bash -n "$$f" || { echo "  ✗ $$f"; exit 1; }; done
	@echo "  ✓ codex hooks/*.sh syntax"
	@for f in adapters/gemini/hooks/*.sh; do bash -n "$$f" || { echo "  ✗ $$f"; exit 1; }; done
	@echo "  ✓ gemini hooks/*.sh syntax"
	@python3 -c "import ast; ast.parse(open('hooks/lib/session_state.py').read())" && echo "  ✓ hooks/lib/session_state.py syntax"
	@python3 -m json.tool adapters/codex/plugins/rolepod/.codex-plugin/plugin.json >/dev/null && echo "  ✓ codex plugin.json"
	@python3 -m json.tool adapters/codex/plugins/rolepod/hooks/hooks.json >/dev/null && echo "  ✓ codex hooks.json"
	@python3 -m json.tool adapters/gemini/gemini-extension.json >/dev/null && echo "  ✓ gemini-extension.json"
	@python3 -m json.tool adapters/gemini/hooks/hooks.json >/dev/null && echo "  ✓ gemini hooks.json"
	@python3 -m json.tool adapters/claude/.claude-plugin/plugin.json >/dev/null && echo "  ✓ claude plugin.json"
	@python3 -m json.tool adapters/claude/.claude-plugin/marketplace.json >/dev/null && echo "  ✓ claude marketplace.json"
	@python3 -m json.tool adapters/claude/hooks.json >/dev/null && echo "  ✓ claude hooks.json"
	@python3 -c "import pathlib, tomllib; [tomllib.loads(p.read_text()) for p in pathlib.Path('adapters/codex/plugins/rolepod/agents').glob('*.toml')]" && echo "  ✓ codex agents/*.toml"
	@python3 -c "import pathlib, tomllib; [tomllib.loads(p.read_text()) for p in pathlib.Path('adapters/gemini/commands').glob('*.toml')]" && echo "  ✓ gemini commands/*.toml"
	@$(MAKE) -s test-render-clean
	@$(MAKE) -s test-lean-surface
	@echo "  → static checks passed"

# lean-surface — anti-drift guards that lock in the Core 10 invariants:
#   - rendered entry doc size caps
#   - Tier 0 + Tier 1 visible skill count (Core 10: 1 + 9 = 10)
#   - filesystem skill dirs = 10 (Core 10 only)
#   - no tier: 3 / redirect_to shim fields remain
#   - deleted legacy skill directories stay absent
#   - core skills include agent-available + no-agent fallback paths
#   - core skills include Full Rolepod enhancement note
#   - write-spec includes approval gate + self-review
#   - core skill fallback sections concise (≤ 25 lines)
#   - no full 18-agent table leaked into entry docs
#   - all 18 agents covered by model-tier policy
#   - no competitor brand refs in source / entry docs
#   - skill-index.md render reproducible under LC_ALL=C
# Wired into test-static so every release gate sees it.
test-lean-surface:
	@bash tests/static/lean-surface.sh

# render-clean — run the renderer, then:
#   (a) assert core/fragments/ has no uncommitted diff (catches stale
#       committed fragment vs current generator output — the drift that
#       bit us on the skill-index.md tier switch).
#   (b) assert build/rendered/ produced expected entry docs.
#   (c) assert no `{{INCLUDE: ...}}` placeholders leaked into rendered
#       output (template directive wasn't resolved).
#
# build/rendered/ itself is gitignored (per build/rendered/.gitignore) so
# we don't git-diff it; we instead check structural invariants directly.
test-render-clean:
	@bash build/render.sh --target=all >/dev/null
	@if ! git diff --quiet -- core/fragments/ 2>/dev/null; then \
		echo "  ✗ render-clean: core/fragments/ has uncommitted diff after build/render.sh."; \
		echo "    Run: make render && git add core/fragments/ && commit."; \
		git diff --stat -- core/fragments/; \
		exit 1; \
	fi
	@if ! git diff --quiet -- .claude-plugin/ plugins/rolepod/ 2>/dev/null; then \
		echo "  ✗ render-clean: committed Claude marketplace tree drifted from build/render.sh output."; \
		echo "    Run: make render && git add .claude-plugin/ plugins/rolepod/ && commit."; \
		git diff --stat -- .claude-plugin/ plugins/rolepod/; \
		exit 1; \
	fi
	@for f in build/rendered/codex/AGENTS.md build/rendered/gemini/GEMINI.md; do \
		[ -f "$$f" ] || { echo "  ✗ render-clean: expected output missing: $$f"; exit 1; }; \
	done
	@[ -f .claude-plugin/marketplace.json ] && [ -f plugins/rolepod/.claude-plugin/plugin.json ] || { echo "  ✗ render-clean: committed Claude marketplace tree missing"; exit 1; }
	@[ ! -f plugins/rolepod/CLAUDE.md ] || { echo "  ✗ render-clean: Claude ships no entry doc — plugins/rolepod/CLAUDE.md should not exist"; exit 1; }
	@leak_files=$$(grep -rl '{{INCLUDE:' build/rendered/ plugins/rolepod/ 2>/dev/null || true); \
	if [ -n "$$leak_files" ]; then \
		echo "  ✗ render-clean: unresolved {{INCLUDE: ...}} placeholders in:"; \
		echo "$$leak_files" | sed 's/^/      /'; \
		exit 1; \
	fi
	@echo "  ✓ render-clean: core/fragments/ + committed Claude marketplace tree match generator output"
	@echo "  ✓ render-clean: codex AGENTS.md + gemini GEMINI.md present, no {{INCLUDE}} leak"

test-integration:
	@echo "── test-integration ──"
	@bash tests/integration/run.sh

# Default `make test` = static gate. Static covers render-clean + lean-surface
# invariants (~70 checks) + syntax + JSON/TOML parse. Rolepod does not ship
# `claude -p` headless behavior tests — the framework targets interactive
# Claude Code sessions, which `-p` single-turn mode does not exercise.
# Routing correctness is proven structurally by lean-surface (router refs
# Core 10) and integration fixtures (skill body content).
test: test-static

# Full local sweep — static + integration structural fixtures.
test-all: test-static test-integration

render:
	@bash build/render.sh --target=all

install:
	@./install.sh --target=claude --force
