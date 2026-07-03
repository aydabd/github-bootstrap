# =============================================================================
# GitHub Bootstrap — Makefile
# =============================================================================
# Zero manual setup — `make install` bootstraps everything automatically:
#   1. Bootstraps selected env manager tooling if needed (micromamba, mise, or system)
#   2. Installs pre-commit Git hooks
#
# Quick start:
#   make install              Bootstrap env + hooks
#   make lint                 Auto-format + lint (local dev)
#   LINT_MODE=check make lint Check-only (CI mode, no auto-fix)
#   make test                 Trigger repository creation tests
#
# Env manager options:
#   ENV_MANAGER=micromamba (default)
#   ENV_MANAGER=mise
#   ENV_MANAGER=system
# =============================================================================

.DEFAULT_GOAL := help

SHELL := /bin/bash

.PHONY: help install install-hooks setup-env lint test clean

# =============================================================================
# Configuration
# =============================================================================
MAMBA_ENV  := github-bootstrap
MAMBA_SPEC := $(CURDIR)/environment.yml
MICROMAMBA ?= $(CURDIR)/.provider/bin/micromamba
MISE ?= $(CURDIR)/.provider/bin/mise

# LINT_MODE: fix (default, local dev) or check (CI, no auto-fix)
LINT_MODE ?= fix
SHOW_COMMANDS ?= 1

ifeq ($(SHOW_COMMANDS),1)
SETUP_TRACE := set -x;
CMD_ECHO := echo
else
SETUP_TRACE :=
CMD_ECHO := :
endif

# Backward compatibility:
# USE_MAMBA=0 implies ENV_MANAGER=system.
USE_MAMBA ?= 1

ENV_MANAGER ?= micromamba

ifeq ($(USE_MAMBA),0)
ifeq ($(origin ENV_MANAGER),default)
ENV_MANAGER := system
endif
endif

ifeq ($(ENV_MANAGER),micromamba)
RUN := $(MICROMAMBA) run -n $(MAMBA_ENV)
else ifeq ($(ENV_MANAGER),mise)
RUN := $(MISE) exec --
else
RUN :=
endif

# Build directory for stamp files
BUILD_DIR := build

define mamba_env_exists
	$(MICROMAMBA) env list --json 2>/dev/null | grep -q '/$(MAMBA_ENV)"'
endef

# Stamp file prevents redundant setup-env re-checks within a single make invocation
ENV_STAMP := $(BUILD_DIR)/.env-stamp

# =============================================================================
# Help
# =============================================================================
help: ## Show available make targets
	@echo "GitHub Bootstrap — Available Commands:"
	@echo ""
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

# =============================================================================
# Environment Setup
# =============================================================================
setup-env: ## Setup selected environment manager (ENV_MANAGER=micromamba|mise|system)
	@set -e; $(SETUP_TRACE) \
	case "$(ENV_MANAGER)" in \
		micromamba) \
			if [ -f "$(ENV_STAMP)" ] && $(call mamba_env_exists) 2>/dev/null; then \
				: ; \
			else \
				if [ ! -x "$(MICROMAMBA)" ]; then \
					echo "Bootstrapping project-local micromamba binary..."; \
					bash scripts/bootstrap-provider-binary.sh micromamba "$(MICROMAMBA)"; \
				fi; \
				if ! $(call mamba_env_exists); then \
					echo "Creating environment '$(MAMBA_ENV)'..."; \
					$(MICROMAMBA) create -y -f $(MAMBA_SPEC); \
				elif [ "$(CI)" != "true" ]; then \
					$(MICROMAMBA) env update -n $(MAMBA_ENV) -f $(MAMBA_SPEC); \
				fi; \
				echo "Micromamba environment '$(MAMBA_ENV)' is ready."; \
				mkdir -p $(BUILD_DIR) && touch $(ENV_STAMP); \
			fi; \
			;; \
		mise) \
			if [ ! -x "$(MISE)" ]; then \
				echo "Bootstrapping project-local mise binary..."; \
				bash scripts/bootstrap-provider-binary.sh mise "$(MISE)"; \
			fi; \
			if [ ! -x "$(MISE)" ]; then \
				echo "Failed to bootstrap mise binary at $(MISE)."; \
				exit 1; \
			fi; \
			PATH="$(dir $(MISE)):$$PATH" $(MISE) install; \
			PATH="$(dir $(MISE)):$$PATH" $(MISE) tasks run install-tools; \
			if ! command -v xmllint >/dev/null 2>&1; then \
				echo "Missing required tool: xmllint"; \
				echo "Install libxml2-utils (or equivalent package) and retry."; \
				exit 1; \
			fi; \
			mkdir -p $(BUILD_DIR); \
			;; \
		system) \
			missing=0; \
			for tool in pre-commit ec shellcheck shfmt xmllint taplo yamllint markdownlint prettier terraform; do \
				if ! command -v $$tool >/dev/null 2>&1; then \
					echo "Missing required tool: $$tool"; \
					missing=1; \
				fi; \
			done; \
			if [ $$missing -ne 0 ]; then \
				echo "Install required tools for system mode and retry."; \
				exit 1; \
			fi; \
			mkdir -p $(BUILD_DIR); \
			;; \
		*) \
			echo "Unsupported ENV_MANAGER '$(ENV_MANAGER)'"; \
			exit 1; \
			;; \
	esac

install: setup-env ## Setup env manager and install pre-commit hooks
	@$(CMD_ECHO) "+ $(MAKE) --no-print-directory _install-hooks"
	@$(MAKE) --no-print-directory _install-hooks
	@echo "Done. Environment manager: $(ENV_MANAGER)"

install-hooks: setup-env ## (Re-)install pre-commit hooks into .git/hooks
	@$(CMD_ECHO) "+ $(MAKE) --no-print-directory _install-hooks"
	@$(MAKE) --no-print-directory _install-hooks

# Internal: install hooks and inject conda PATH so git commit finds all tools.
_install-hooks:
	@$(CMD_ECHO) "+ $(RUN) pre-commit install"
	@$(RUN) pre-commit install
	@$(CMD_ECHO) "+ $(RUN) pre-commit install --hook-type commit-msg"
	@$(RUN) pre-commit install --hook-type commit-msg
ifeq ($(ENV_MANAGER),micromamba)
	@ENV_BIN="$$( $(MICROMAMBA) info -n $(MAMBA_ENV) 2>/dev/null | awk '/env location/{print $$NF}')/bin"; \
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
ifeq ($(ENV_MANAGER),mise)
	@for hook in pre-commit commit-msg; do \
		hook_file=".git/hooks/$$hook"; \
		if [ -f "$$hook_file" ] && ! grep -q 'mise-env-path' "$$hook_file"; then \
			{ head -1 "$$hook_file"; \
			echo "# mise-env-path"; \
			echo 'ROOT_DIR="$$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; if [ -x "$$ROOT_DIR/.provider/bin/mise" ]; then eval "$$(cd "$$ROOT_DIR" && .provider/bin/mise activate bash --shims)"; fi'; \
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
	@$(CMD_ECHO) "+ $(RUN) pre-commit install --install-hooks"
	@$(RUN) pre-commit install --install-hooks >/dev/null 2>&1 || true
	@$(CMD_ECHO) "+ LINT_MODE=$(LINT_MODE) $(RUN) pre-commit run --all-files --color=always"
	@LINT_MODE=$(LINT_MODE) $(RUN) pre-commit run --all-files --color=always

# =============================================================================
# Testing
# =============================================================================
test: ## Trigger repository creation tests via GitHub Actions
	@echo "Running repository creation tests..."
	@$(CMD_ECHO) "+ gh workflow run test-repository-creation.yml --field test_repo_name=automated-test --field languages=language-agnostic-only --field cleanup_after_test=true"
	@gh workflow run test-repository-creation.yml \
		--field test_repo_name="automated-test" \
		--field languages="language-agnostic-only" \
		--field cleanup_after_test="true"
	@echo "Test triggered. Check: gh run list --workflow=test-repository-creation.yml"

# =============================================================================
# Clean
# =============================================================================
clean: ## Remove build artefacts and cache directories
	find . -name "*.tmp" -delete 2>/dev/null || true
	rm -rf $(BUILD_DIR)/
	@find . -name ".DS_Store" -delete
	@echo "Cleanup complete"
