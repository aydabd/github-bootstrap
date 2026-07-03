# =============================================================================
# {{REPOSITORY_NAME}} — Makefile (system)
# =============================================================================

.DEFAULT_GOAL := help
SHELL := /bin/bash

.PHONY: help install install-hooks setup-env lint test clean

LINT_MODE ?= fix
BUILD_DIR := build

help: ## Show available make targets
	@echo "{{REPOSITORY_NAME}} — Available Commands (system):"
	@echo ""
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

setup-env: ## Validate required tools are available on PATH
	@missing=0; \
	for tool in pre-commit ec shellcheck shfmt xmllint taplo yamllint markdownlint prettier; do \
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

test: setup-env ## Run tests (update this target for your language/framework)
	@echo "Update this target for your project's test framework."

clean: ## Remove build artefacts and cache directories
	find . -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name '.pytest_cache' -exec rm -rf {} + 2>/dev/null || true
	rm -rf $(BUILD_DIR)/
