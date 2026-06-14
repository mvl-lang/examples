# crud_api — REST API over SQLite with audit logging
#
# Inspired by: "I Ditched FastAPI for Rust" (Aaron Philip, May 2026)
#
# Usage:
#   make run                     # Run with defaults (port 8080)
#   make run ARGS="--port 9090"  # Run with CLI args
#   make test                    # Run unit tests
#   make test-api                # Run API integration tests (server must be running)
#   make seed                    # Seed database from CSV
#   make clean                   # Remove build artifacts

.PHONY: help build run run-dev run-json test test-unit test-api test-api-list test-api-crud
.PHONY: seed db-reset audit-tail audit-clear fmt check lint assurance smoke clean

.DEFAULT_GOAL := help

MVL       := mvl
MVL_FLAGS := --stdlib=proven
DIR       := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Default paths
DB_PATH    := /tmp/crud_api.db
AUDIT_PATH := ./audit.jsonl
PORT       := 8080
HOST       := 127.0.0.1

SRCS := $(DIR)models.mvl $(DIR)config.mvl $(DIR)db.mvl $(DIR)seed.mvl $(DIR)handlers.mvl $(DIR)main.mvl

# ── Help ───────────────────────────────────────────────────────────────────────

help: ## Show this help
	@echo "crud_api — REST API over SQLite with audit logging"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# ── Build ──────────────────────────────────────────────────────────────────────
guard-mvl:
	$(MVL) --version > /dev/null 2>&1 || { echo "Run 'make build' from repo root first."; exit 1; }

build: ## Build the application
	$(MVL) build $(MVL_FLAGS) $(DIR)main.mvl

smoke: ## Smoke-test: build binary (proves compilation)
	$(MVL) build $(MVL_FLAGS) $(DIR)main.mvl

# ── Run ────────────────────────────────────────────────────────────────────────

run: ## Start server with defaults (port 8080)
	$(MVL) run $(MVL_FLAGS) $(DIR)main.mvl -- $(ARGS)

run-dev: ## Start server with debug logging (plain format)
	CRUD_API_LOG_LEVEL=debug CRUD_API_LOG_FORMAT=plain \
	$(MVL) run $(MVL_FLAGS) $(DIR)main.mvl -- $(ARGS)

run-json: ## Start server with JSON log format
	CRUD_API_LOG_FORMAT=json \
	$(MVL) run $(MVL_FLAGS) $(DIR)main.mvl -- $(ARGS)

# ── Testing ────────────────────────────────────────────────────────────────────

test: test-unit ## Run all tests

test-unit: ## Run unit tests (config_test.mvl, main_test.mvl)
	$(MVL) test $(MVL_FLAGS) $(DIR)

test-llvm: ## Run tests via LLVM backend
	$(MVL) test $(MVL_FLAGS) $(DIR) --backend=llvm

# API integration tests (requires server running in another terminal)
test-api: test-api-list test-api-crud ## Run API integration tests

test-api-list:
	@echo "==> GET /users"
	@curl -sf http://$(HOST):$(PORT)/users | jq . || echo "FAILED (is server running?)"

test-api-crud:
	@echo ""
	@echo "==> POST /users (create)"
	@curl -sf -X POST http://$(HOST):$(PORT)/users \
		-H 'Content-Type: application/json' \
		-d '{"name":"Test User","email":"test@example.com"}' | jq .
	@echo ""
	@echo "==> GET /users (list after create)"
	@curl -sf http://$(HOST):$(PORT)/users | jq .
	@echo ""
	@echo "==> GET /users/1"
	@curl -sf http://$(HOST):$(PORT)/users/1 | jq . || echo "Not found"
	@echo ""
	@echo "==> PUT /users/1 (update)"
	@curl -sf -X PUT http://$(HOST):$(PORT)/users/1 \
		-H 'Content-Type: application/json' \
		-d '{"name":"Updated User","email":"updated@example.com"}' | jq . || echo "Not found"
	@echo ""
	@echo "==> DELETE /users/1"
	@curl -sf -X DELETE http://$(HOST):$(PORT)/users/1 && echo "Deleted (204 No Content)" || echo "Not found"
	@echo ""
	@echo "==> GET /users (list after delete)"
	@curl -sf http://$(HOST):$(PORT)/users | jq .

# ── Database ───────────────────────────────────────────────────────────────────

seed: ## Seed database from users.csv
	$(MVL) run $(MVL_FLAGS) $(DIR)main.mvl -- --seed-file users.csv

db-reset: ## Delete database file
	rm -f $(DB_PATH)
	@echo "Database removed: $(DB_PATH)"

# ── Audit ──────────────────────────────────────────────────────────────────────

audit-tail: ## Follow audit log (requires jq)
	@tail -f $(AUDIT_PATH) | jq .

audit-clear: ## Clear audit log
	rm -f $(AUDIT_PATH)
	@echo "Audit log cleared: $(AUDIT_PATH)"

# ── Code Quality ───────────────────────────────────────────────────────────────

fmt: ## Format all source files
	$(MVL) fmt $(DIR)

check: ## Type-check all source files
	@for f in $(SRCS); do \
		$(MVL) check $(MVL_FLAGS) "$$f"; \
	done

lint: ## Lint all source files
	@for f in $(SRCS); do \
		$(MVL) lint "$$f"; \
	done

# ── prove ────────────────────────────────────────────────────────────────────
prove: guard-mvl ## Prove per-call-site refinement proof layer breakdown
	$(MVL) prove --verbose $(DIR)

# ── Assurance ──────────────────────────────────────────────────────────────────

assurance: ## Generate assurance report
	$(MVL) assurance $(MVL_FLAGS) $(DIR)

assurance-verbose: ## Generate verbose assurance report
	$(MVL) assurance $(MVL_FLAGS) --verbose $(DIR)

# ── Clean ──────────────────────────────────────────────────────────────────────

clean: ## Remove build artifacts and temporary files
	rm -rf target/
	rm -f $(DB_PATH)
	rm -f $(AUDIT_PATH)
	rm -rf $(TMPDIR)mvl_build_crud_api
