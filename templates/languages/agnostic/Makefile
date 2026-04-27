# =============================================================================
# {{REPOSITORY_NAME}} — Makefile
# =============================================================================
# Zero manual setup — `make install` bootstraps everything automatically:
#   1. Installs micromamba env (pre-commit, prettier, yamllint, etc.)
#   2. Installs pre-commit Git hooks
#
# Quick start:
#   make install              Bootstrap env + hooks
#   make lint                 Auto-format + lint (local dev)
#   LINT_MODE=check make lint Check-only (CI mode, no auto-fix)
#   make test                 Run tests
#
# Skip micromamba: USE_MAMBA=0 make lint   (uses system tools)
# =============================================================================

.DEFAULT_GOAL := help

SHELL := /bin/bash

.PHONY: help install install-hooks setup-env lint test clean

# =============================================================================
# Configuration
# =============================================================================
MAMBA_ENV  := {{REPOSITORY_NAME}}
MAMBA_SPEC := $(CURDIR)/environment.yml

# LINT_MODE: fix (default, local dev) or check (CI, no auto-fix)
LINT_MODE ?= fix

# USE_MAMBA controls whether commands run via micromamba or directly.
# Set USE_MAMBA=0 for CI runners that pre-install tools, or envs without micromamba.
USE_MAMBA ?= 1

ifeq ($(USE_MAMBA),0)
MAMBA_RUN :=
else
MAMBA_RUN := micromamba run -n $(MAMBA_ENV)
endif

# Build directory for stamp files
BUILD_DIR := build

# =============================================================================
# Helper: Check if micromamba environment exists
# =============================================================================
define mamba_env_exists
	micromamba env list --json 2>/dev/null | grep -q '/$(MAMBA_ENV)"'
endef

# Stamp file prevents redundant setup-env re-checks within a single make invocation
ENV_STAMP := $(BUILD_DIR)/.env-stamp

# =============================================================================
# Help
# =============================================================================
help: ## Show available make targets
	@echo "{{REPOSITORY_NAME}} — Available Commands:"
	@echo ""
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

# =============================================================================
# Environment Setup
# =============================================================================
setup-env: ## Setup isolated environment with micromamba (skip with USE_MAMBA=0)
	@if [ "$(USE_MAMBA)" = "0" ]; then \
		echo "Skipping micromamba setup (USE_MAMBA=0)"; \
	elif [ -f "$(ENV_STAMP)" ] && $(call mamba_env_exists) 2>/dev/null; then \
		: ; \
	else \
		if ! command -v micromamba >/dev/null 2>&1; then \
			echo "Installing micromamba..."; \
			set -o pipefail; curl -L micro.mamba.pm/install.sh | $(SHELL); \
		fi; \
		if ! $(call mamba_env_exists); then \
			echo "Creating environment '$(MAMBA_ENV)'..."; \
			micromamba create -y -f $(MAMBA_SPEC); \
		elif [ "$(CI)" != "true" ]; then \
			micromamba env update -n $(MAMBA_ENV) -f $(MAMBA_SPEC); \
		fi; \
		echo "Micromamba environment '$(MAMBA_ENV)' is ready."; \
		mkdir -p $(BUILD_DIR) && touch $(ENV_STAMP); \
	fi

install: setup-env ## Create the micromamba env and install pre-commit hooks
	@$(MAKE) --no-print-directory _install-hooks
	@echo "Done. Activate with: micromamba activate $(MAMBA_ENV)"

install-hooks: setup-env ## (Re-)install pre-commit hooks into .git/hooks
	@$(MAKE) --no-print-directory _install-hooks

# Internal: install hooks and inject conda PATH so git commit finds all tools.
_install-hooks:
	@$(MAMBA_RUN) pre-commit install
	@$(MAMBA_RUN) pre-commit install --hook-type commit-msg
ifeq ($(USE_MAMBA),1)
	@# Prepend conda bin to PATH in generated hooks so language:system hooks
	@# (ec, prettier, yamllint, etc.) are found when git runs outside the env.
	@ENV_BIN="$$(micromamba info -n $(MAMBA_ENV) 2>/dev/null | awk '/env location/{print $$NF}')/bin"; \
	for hook in pre-commit commit-msg; do \
		hook_file=".git/hooks/$$hook"; \
		if [ -f "$$hook_file" ] && ! grep -q 'conda-env-path' "$$hook_file"; then \
			{ head -1 "$$hook_file"; \
			echo "# conda-env-path"; \
			echo "export PATH=\"$$ENV_BIN:\$$PATH\""; \
			tail -n +2 "$$hook_file"; \
			} > "$$hook_file.tmp" && mv "$$hook_file.tmp" "$$hook_file" && chmod +x "$$hook_file"; \
		fi; \
	done
endif

# =============================================================================
# Linting
# =============================================================================
# Pre-commit is the single source of truth for ALL quality checks.
# LINT_MODE=fix  → auto-fix formatting (default for local development)
# LINT_MODE=check → check-only, fail on violations (CI)
lint: setup-env ## Run all checks via pre-commit (LINT_MODE=fix|check)
	@echo "Running all checks via pre-commit (LINT_MODE=$(LINT_MODE))..."
	@$(MAMBA_RUN) pre-commit install --install-hooks >/dev/null 2>&1 || true
	@LINT_MODE=$(LINT_MODE) $(MAMBA_RUN) pre-commit run --all-files --color=always
	@echo "All checks passed"

# =============================================================================
# Testing
# =============================================================================
test: setup-env ## Run tests (update this target for your language/framework)
	@echo "Update this target for your project's test framework."
	@echo "Examples:"
	@echo "  Python:     pytest tests/"
	@echo "  Go:         go test ./..."
	@echo "  TypeScript: npm test"
	@echo "  Java:       ./gradlew test"

# =============================================================================
# Clean
# =============================================================================
clean: ## Remove build artefacts and cache directories
	find . -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name '.pytest_cache' -exec rm -rf {} + 2>/dev/null || true
	rm -rf $(BUILD_DIR)/
