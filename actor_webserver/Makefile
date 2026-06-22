# actor_webserver — concurrent HTTP server with actor-per-request pattern
#
# Uses pkg-http for HTTP types, parsing, and response serialization.
# Each accepted TCP connection is handed to a fresh RequestHandler actor that
# owns the socket exclusively (iso capability).
#
# Usage:
#   make run                         # Start server on 127.0.0.1:8080
#   make run ARGS="--port 9090"      # Run with CLI args
#   make test                        # Run unit tests
#   make clean                       # Remove build artifacts

.PHONY: help version install build run run-dev test test-unit test-llvm
.PHONY: fmt check lint prove assurance assurance-verbose coverage smoke clean

.DEFAULT_GOAL := help

MVL       := mvl
MVL_FLAGS := --stdlib=proven
DIR       := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

PORT := 8080
HOST := 127.0.0.1

# ── Help ───────────────────────────────────────────────────────────────────────

help: ## Show this help
	@echo "actor_webserver — concurrent HTTP server (pkg-http + actors)"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

version: ## Show package version from mvl.toml
	@grep '^version' $(DIR)mvl.toml | head -1 | sed 's/.*= *"\([^"]*\)".*/\1/'

# ── Build ──────────────────────────────────────────────────────────────────────

install: ## Fetch and verify all dependencies from mvl.lock
	$(MVL) install

build: install ## Build the application
	$(MVL) build $(MVL_FLAGS) $(DIR)main.mvl

smoke: install ## Smoke-test: build binary (proves compilation)
	$(MVL) build $(MVL_FLAGS) $(DIR)main.mvl

# ── Run ────────────────────────────────────────────────────────────────────────

run: install ## Start server with defaults (port 8080)
	$(MVL) run $(MVL_FLAGS) $(DIR)main.mvl -- $(ARGS)

run-dev: install ## Start server with debug logging (plain format)
	WEBSERVER_LOG_LEVEL=debug WEBSERVER_LOG_FORMAT=plain \
	$(MVL) run $(MVL_FLAGS) $(DIR)main.mvl -- $(ARGS)

# ── Testing ────────────────────────────────────────────────────────────────────

test: test-unit ## Run all tests

test-unit: install ## Run unit tests (config_test.mvl, main_test.mvl)
	$(MVL) test $(MVL_FLAGS) $(DIR)

test-llvm: install ## Run tests via LLVM backend
	$(MVL) test $(MVL_FLAGS) $(DIR) --backend=llvm

# ── Code Quality ───────────────────────────────────────────────────────────────

fmt: install ## Format all source files
	$(MVL) fmt $(DIR)

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
	rm -rf $(TMPDIR)mvl_build_actor_webserver
