# anthropic_chat — Anthropic Claude API example
#
# Demonstrates pkg-anthropic SDK with IFC-aware Secret/Tainted types.
# Requires ANTHROPIC_API_KEY in the environment for `make run`.
#
# Usage:
#   make run                         # Send a message to Claude
#   make smoke                       # Verify graceful no-key error
#   make check                       # Type-check sources

.PHONY: help version install build run run-dev test test-unit test-llvm
.PHONY: fmt check lint prove assurance assurance-verbose coverage smoke clean

.DEFAULT_GOAL := help

MVL       := mvl
MVL_FLAGS := --stdlib=proven
DIR       := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# ── Help ───────────────────────────────────────────────────────────────────────

help: ## Show this help
	@echo "anthropic_chat — Claude API client (pkg-anthropic)"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

version: ## Show package version from mvl.toml
	@grep '^version' $(DIR)mvl.toml | head -1 | sed 's/.*= *"\([^"]*\)".*/\1/'

# ── Build ──────────────────────────────────────────────────────────────────────

install: ## Fetch and verify all dependencies from mvl.lock
	$(MVL) install

build: install ## Build the application
	$(MVL) build $(MVL_FLAGS) $(DIR)main.mvl

# ── Run ────────────────────────────────────────────────────────────────────────

run: install ## Send a message to Claude (requires ANTHROPIC_API_KEY)
	$(MVL) run $(MVL_FLAGS) $(DIR)main.mvl -- $(ARGS)

run-dev: install ## Run with debug logging
	ANTHROPIC_LOG_LEVEL=debug \
	$(MVL) run $(MVL_FLAGS) $(DIR)main.mvl -- $(ARGS)

# ── Testing ────────────────────────────────────────────────────────────────────

test: test-unit ## Run all tests

test-unit: install ## Run unit tests
	$(MVL) test $(MVL_FLAGS) $(DIR)

test-llvm: install ## Run tests via LLVM backend
	$(MVL) test $(MVL_FLAGS) $(DIR) --backend=llvm

# ── Code Quality ───────────────────────────────────────────────────────────────

fmt: install ## Format all source files
	$(MVL) fmt $(DIR)

check: install ## Type-check the example's source files (not .mvl/pkg/)
	$(MVL) check $(MVL_FLAGS) $(DIR)main.mvl

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

# ── Smoke ──────────────────────────────────────────────────────────────────────

smoke: install ## Smoke-test: build + verify graceful no-key error
	@OK="\033[32m✓\033[0m"; FAIL="\033[31m✗\033[0m"; \
	$(MVL) build $(MVL_FLAGS) $(DIR)main.mvl > /dev/null 2>&1 || { printf "  $$FAIL  build failed\n"; exit 1; }; \
	out=$$(env -u ANTHROPIC_API_KEY $(MVL) run $(MVL_FLAGS) $(DIR)main.mvl 2>&1); \
	if echo "$$out" | grep -q "ANTHROPIC_API_KEY"; then \
		printf "  $$OK  anthropic_chat: graceful no-key error\n"; \
	else \
		printf "  $$FAIL  anthropic_chat: unexpected output\n"; \
		echo "$$out"; \
		exit 1; \
	fi

# ── Clean ──────────────────────────────────────────────────────────────────────

clean: ## Remove build artifacts
	rm -rf target/
	rm -rf $(TMPDIR)mvl_build_anthropic_chat
