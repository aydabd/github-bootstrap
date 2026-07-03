# =============================================================================
# {{REPOSITORY_NAME}} — Makefile (system)
# =============================================================================

.DEFAULT_GOAL := help
SHELL := /bin/bash

.PHONY: help install install-hooks setup-env lint test coverage clean

LINT_MODE ?= fix
BUILD_DIR := build

help: ## Show available make targets
	@echo "{{REPOSITORY_NAME}} — Available Commands (system):"
	@echo ""
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

setup-env: ## Validate required tools are available on PATH
	@missing=0; \
	for tool in pre-commit ec shellcheck shfmt xmllint taplo yamllint markdownlint prettier go golangci-lint; do \
		if ! command -v $$tool >/dev/null 2>&1; then \
			echo "Missing required tool: $$tool"; \
			missing=1; \
		fi; \
	done; \
	if [ $$missing -ne 0 ]; then \
		echo "Install required tools on your machine and retry."; \
		exit 1; \
	fi
	@mkdir -p $(BUILD_DIR)

install: setup-env ## Install pre-commit hooks
	@$(MAKE) --no-print-directory _install-hooks

install-hooks: setup-env ## (Re-)install pre-commit hooks
	@$(MAKE) --no-print-directory _install-hooks

_install-hooks:
	@pre-commit install
	@pre-commit install --hook-type commit-msg

lint: setup-env ## Run all checks via pre-commit
	@echo "Running all checks via pre-commit (LINT_MODE=$(LINT_MODE))..."
	@pre-commit install --install-hooks >/dev/null 2>&1 || true
	@LINT_MODE=$(LINT_MODE) pre-commit run --all-files --color=always

test: setup-env ## Run all Go tests
	go test ./...

coverage: setup-env ## Run Go tests with coverage report
	go test -coverprofile=$(BUILD_DIR)/coverage.out ./...
	go tool cover -html=$(BUILD_DIR)/coverage.out -o $(BUILD_DIR)/coverage.html
	@echo "Coverage report: $(BUILD_DIR)/coverage.html"

clean: ## Remove build artefacts and cache directories
	find . -name "*.tmp" -delete 2>/dev/null || true
	rm -rf $(BUILD_DIR)/
