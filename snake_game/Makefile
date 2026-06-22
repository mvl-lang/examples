# snake_game — terminal Snake game built on pkg-tui
#
# Uses pkg-tui for raw-mode terminal control, keypress input, and ANSI styles.
#
# Usage:
#   make run                         # Play the game (requires a real TTY)
#   make test                        # Run unit tests
#   make smoke                       # Build-only check (no terminal needed)

.PHONY: help version install build run run-dev test test-unit test-llvm
.PHONY: fmt check lint prove assurance assurance-verbose coverage smoke clean

.DEFAULT_GOAL := help

MVL       := mvl
MVL_FLAGS := --stdlib=proven
DIR       := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# ── Help ───────────────────────────────────────────────────────────────────────

help: ## Show this help
	@echo "snake_game — terminal Snake game (pkg-tui)"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

version: ## Show package version from mvl.toml
	@grep '^version' $(DIR)mvl.toml | head -1 | sed 's/.*= *"\([^"]*\)".*/\1/'

# ── Build ──────────────────────────────────────────────────────────────────────

install: ## Fetch and verify all dependencies from mvl.lock
	$(MVL) install

build: install ## Build the application
	$(MVL) build $(MVL_FLAGS) $(DIR)main.mvl

smoke: install ## Smoke-test: build binary (proves compilation without a tty)
	$(MVL) build $(MVL_FLAGS) $(DIR)main.mvl

# ── Run ────────────────────────────────────────────────────────────────────────

run: install ## Play the game (requires a real TTY)
	$(MVL) run $(MVL_FLAGS) $(DIR)main.mvl -- $(ARGS)

run-dev: install ## Play with debug-level snake state logging on stderr
	SNAKE_LOG_LEVEL=debug \
	$(MVL) run $(MVL_FLAGS) $(DIR)main.mvl -- $(ARGS)

# ── Testing ────────────────────────────────────────────────────────────────────

test: test-unit ## Run all tests

test-unit: install ## Run unit tests (game_test.mvl, input.mvl)
	$(MVL) test $(MVL_FLAGS) $(DIR)

test-llvm: install ## Run tests via LLVM backend
	$(MVL) test $(MVL_FLAGS) $(DIR) --backend=llvm

# ── Code Quality ───────────────────────────────────────────────────────────────

fmt: install ## Format all source files (top-level .mvl files only; skips .mvl/pkg/)
	$(MVL) fmt $(DIR)*.mvl

check: install ## Type-check all source files
	$(MVL) check $(MVL_FLAGS) $(DIR)

lint: install ## Lint all source files
	$(MVL) lint $(MVL_FLAGS) $(DIR)

prove: install ## Prove per-call-site refinement proof layer breakdown
	$(MVL) prove $(MVL_FLAGS) $(DIR)

# ── Assurance ──────────────────────────────────────────────────────────────────

assurance: install ## Generate assurance report
	$(MVL) assurance $(MVL_FLAGS) $(DIR)

assurance-verbose: install ## Generate verbose assurance report
	$(MVL) assurance $(MVL_FLAGS) --verbose $(DIR)

coverage: install ## Generate coverage report
	$(MVL) test $(MVL_FLAGS) --coverage $(DIR)

# ── Clean ──────────────────────────────────────────────────────────────────────

clean: ## Remove build artifacts
	rm -rf target/
	rm -rf $(TMPDIR)mvl_build_snake_game
