# sqlite_basic — SQLite CRUD example in MVL
#
# Usage:
#   make run          # Run the demonstration
#   make test         # Run unit tests
#   make assurance    # Full assurance report

.PHONY: help version install check prove test assurance assurance-verbose coverage fmt lint run smoke clean

.DEFAULT_GOAL := help

MVL := mvl
DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

help: ## Show this help
	@echo "sqlite_basic — SQLite CRUD demonstration in MVL"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

version: ## Show package version from mvl.toml
	@grep '^version' $(DIR)mvl.toml | head -1 | sed 's/.*= *"\([^"]*\)".*/\1/'

install: ## Fetch and verify all dependencies from mvl.lock
	$(MVL) install

check: install ## Type-check all source files
	$(MVL) check $(DIR)

prove: install ## Show per-call-site refinement proof breakdown
	$(MVL) prove $(DIR)

test: install ## Run unit tests (db_test.mvl + main_test.mvl)
	$(MVL) test $(DIR)

assurance: install ## Generate assurance report
	$(MVL) assurance $(DIR)

assurance-verbose: install ## Generate verbose assurance report
	$(MVL) assurance --verbose $(DIR)

coverage: install ## Generate branch coverage report
	$(MVL) test --coverage $(DIR)

fmt: install ## Format all source files
	$(MVL) fmt $(DIR)

lint: install ## Lint all source files
	$(MVL) lint $(DIR)

run: install ## Run the example (in-memory database)
	$(MVL) run $(DIR)main.mvl

smoke: install ## Smoke-test: compile binary without running it
	$(MVL) build $(DIR)main.mvl

clean: ## Remove build artifacts
	rm -rf $(TMPDIR)mvl_build_sqlite_basic
