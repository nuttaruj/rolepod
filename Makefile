# Rolepod release gate. One command per test phase.
#
# Usage:
#   make test-static       — fast (<5s) — syntax + JSON/TOML parse on shipped artifacts
#   make test-workflow     — behavior tests (skips if claude CLI absent)
#   make test-integration  — slow local tests (skips per-case if deps missing)
#   make test              — static + workflow (CI Phase 1 equivalent)
#   make test-all          — all three phases
#
# Each command exits 0 on pass/skip and non-zero only on hard fail.

.PHONY: test test-static test-workflow test-integration test-all render install help

help:
	@echo "Rolepod test commands:"
	@echo "  make test-static            — bash syntax + JSON/TOML parse + render-clean"
	@echo "  make test-workflow          — workflow-behavior parse + skip-clean (cheap)"
	@echo "  make test-workflow-live     — run live claude -p prompts (needs ROLEPOD_RUN_LIVE=1)"
	@echo "  make test-integration       — integration tests (slow, local)"
	@echo "  make test                   — test-static + test-workflow (NO live model calls)"
	@echo "  make test-all               — static + workflow (cheap) + integration"
	@echo "  make test-release           — test-all + test-workflow-live (full gate, costs budget)"
	@echo ""
	@echo "  make render                 — render adapters to build/rendered/"
	@echo "  make install                — install --target=claude --force into ~/.claude/"

test-static:
	@echo "── test-static ──"
	@bash -n install.sh && echo "  ✓ install.sh syntax"
	@bash -n bootstrap.sh && echo "  ✓ bootstrap.sh syntax"
	@bash -n build/render.sh && echo "  ✓ render.sh syntax"
	@for f in hooks/*.sh; do bash -n "$$f" || { echo "  ✗ $$f"; exit 1; }; done
	@echo "  ✓ hooks/*.sh syntax"
	@python3 -c "import ast; ast.parse(open('hooks/lib/session_state.py').read())" && echo "  ✓ hooks/lib/session_state.py syntax"
	@python3 -c "import ast; ast.parse(open('tests/workflow-behavior/parse_case.py').read())" && echo "  ✓ tests/workflow-behavior/parse_case.py syntax"
	@python3 -m json.tool adapters/codex/plugins/rolepod/.codex-plugin/plugin.json >/dev/null && echo "  ✓ codex plugin.json"
	@python3 -m json.tool adapters/codex/plugins/rolepod/hooks/hooks.json >/dev/null && echo "  ✓ codex hooks.json"
	@python3 -m json.tool adapters/gemini/gemini-extension.json >/dev/null && echo "  ✓ gemini-extension.json"
	@python3 -m json.tool adapters/gemini/hooks/hooks.json >/dev/null && echo "  ✓ gemini hooks.json"
	@python3 -m json.tool .claude-plugin/plugin.json >/dev/null && echo "  ✓ claude plugin.json"
	@python3 -c "import pathlib, tomllib; [tomllib.loads(p.read_text()) for p in pathlib.Path('adapters/codex/plugins/rolepod/agents').glob('*.toml')]" && echo "  ✓ codex agents/*.toml"
	@python3 -c "import pathlib, tomllib; [tomllib.loads(p.read_text()) for p in pathlib.Path('adapters/gemini/commands').glob('*.toml')]" && echo "  ✓ gemini commands/*.toml"
	@$(MAKE) -s test-render-clean
	@$(MAKE) -s test-lean-surface
	@echo "  → static checks passed"

# lean-surface — anti-drift guards that lock in the post-refactor invariants:
#   - rendered entry doc size caps
#   - Tier 0 + Tier 1 visible skill count (1 + 11 = 12)
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
	@for f in build/rendered/claude/CLAUDE.md build/rendered/codex/AGENTS.md build/rendered/gemini/GEMINI.md; do \
		[ -f "$$f" ] || { echo "  ✗ render-clean: expected output missing: $$f"; exit 1; }; \
	done
	@leak_files=$$(grep -rl '{{INCLUDE:' build/rendered/ 2>/dev/null || true); \
	if [ -n "$$leak_files" ]; then \
		echo "  ✗ render-clean: unresolved {{INCLUDE: ...}} placeholders in:"; \
		echo "$$leak_files" | sed 's/^/      /'; \
		exit 1; \
	fi
	@echo "  ✓ render-clean: core/fragments/ matches generator output"
	@echo "  ✓ render-clean: build/rendered/ has CLAUDE.md + AGENTS.md + GEMINI.md, no {{INCLUDE}} leak"

test-workflow:
	@echo "── test-workflow ──"
	@bash tests/workflow-behavior/run.sh

# Opt-in live runner. Costs API budget + sends real prompts. Set
# ROLEPOD_RUN_LIVE=1 in the environment OR run target directly.
test-workflow-live:
	@echo "── test-workflow-live (LIVE — costs API budget) ──"
	@ROLEPOD_RUN_LIVE=1 bash tests/workflow-behavior/run.sh

test-integration:
	@echo "── test-integration ──"
	@bash tests/integration/run.sh

# Default `make test` = static + cheap workflow skip. NO live model calls.
test: test-static test-workflow

# Full local sweep w/o live API spend.
test-all: test-static test-workflow test-integration

# Release gate — adds the live workflow run on top of test-all. Run this
# manually before tagging a release.
test-release: test-static test-workflow test-integration test-workflow-live

render:
	@bash build/render.sh --target=all

install:
	@./install.sh --target=claude --force
