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
	@echo "  make test-static       — bash syntax + JSON/TOML parse"
	@echo "  make test-workflow     — workflow-behavior tests (needs claude CLI)"
	@echo "  make test-integration  — integration tests (slow, local)"
	@echo "  make test              — test-static + test-workflow"
	@echo "  make test-all          — all three"
	@echo ""
	@echo "  make render            — render adapters to build/rendered/"
	@echo "  make install           — install --target=claude --force into ~/.claude/"

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
	@echo "  → static checks passed"

test-workflow:
	@echo "── test-workflow ──"
	@bash tests/workflow-behavior/run.sh

test-integration:
	@echo "── test-integration ──"
	@bash tests/integration/run.sh

test: test-static test-workflow

test-all: test-static test-workflow test-integration

render:
	@bash build/render.sh --target=all

install:
	@./install.sh --target=claude --force
