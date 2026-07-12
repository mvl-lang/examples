# pong — terminal Pong built on pkg-tui
#
# The full quality gate lives here. `make all` is the CI-equivalent.
#
# Usage:
#   make run                         # Play the game (requires a real TTY)
#   make check                       # Type-check + refinement bounds
#   make prove                       # Discharge every requires/ensures via Z3
#   make test-rust                   # Unit tests (Rust backend)
#   make coverage                    # Branch coverage report
#   make mcdc                        # MC/DC condition coverage report
#   make assurance                   # 11-req ISPE-style assurance report
#   make all                         # Full quality gate — all of the above

.PHONY: help version install build run smoke
.PHONY: fmt check lint prove
.PHONY: test-rust test-llvm coverage mcdc
.PHONY: assurance assurance-verbose
.PHONY: all clean

.DEFAULT_GOAL := help

MVL       := mvl
MVL_FLAGS := --stdlib=proven
DIR       := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# ── Help ───────────────────────────────────────────────────────────────────────

help: ## Show this help
	@echo "pong — terminal Pong (pkg-tui)"
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

# ── Code Quality ───────────────────────────────────────────────────────────────

fmt: install ## Format all source files (top-level .mvl only; skips .mvl/pkg/)
	$(MVL) fmt $(DIR)*.mvl

check: install ## Type-check all source files
	$(MVL) check $(MVL_FLAGS) $(DIR)

lint: install ## Lint all source files
	$(MVL) lint $(MVL_FLAGS) $(DIR)

prove: install ## Prove per-call-site refinement layer breakdown
	$(MVL) prove $(MVL_FLAGS) --verbose $(DIR)

# ── Testing ────────────────────────────────────────────────────────────────────

test-rust: install ## Run unit tests (models_test / game_test / input_test)
	$(MVL) test $(MVL_FLAGS) $(DIR)

test-llvm: install ## Run tests via LLVM backend
	$(MVL) test $(MVL_FLAGS) $(DIR) --backend=llvm

coverage: install ## Generate branch coverage report
	$(MVL) test $(MVL_FLAGS) --coverage $(DIR)

mcdc: install ## Generate MC/DC condition coverage report
	$(MVL) mcdc $(MVL_FLAGS) --verbose $(DIR)

# ── Assurance ──────────────────────────────────────────────────────────────────

assurance: install ## Generate assurance report (11-req roll-up)
	$(MVL) assurance $(MVL_FLAGS) $(DIR)

assurance-verbose: install ## Generate verbose assurance report
	$(MVL) assurance $(MVL_FLAGS) --verbose $(DIR)

# ── Full quality gate ─────────────────────────────────────────────────────────

all: check test-rust coverage mcdc prove assurance ## Full CI-equivalent quality gate

# ── Clean ──────────────────────────────────────────────────────────────────────

clean: ## Remove build artifacts
	rm -rf target/
	rm -rf $(TMPDIR)mvl_build_pong
