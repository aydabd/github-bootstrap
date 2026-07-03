# =============================================================================
# {{REPOSITORY_NAME}} — Makefile (mise)
# =============================================================================

.DEFAULT_GOAL := help
SHELL := /bin/bash

.PHONY: help install install-hooks setup-env lint test build clean

LINT_MODE ?= fix
BUILD_DIR := build
MISE ?= $(CURDIR)/.provider/bin/mise
RUN := $(MISE) exec --

help: ## Show available make targets
	@echo "{{REPOSITORY_NAME}} — Available Commands (mise):"
	@echo ""
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

setup-env: ## Setup isolated environment with mise
	@if [ ! -x "$(MISE)" ]; then \
		echo "Bootstrapping project-local mise binary..."; \
		bash scripts/bootstrap-provider-binary.sh mise "$(MISE)"; \
	fi
	@if [ ! -x "$(MISE)" ]; then \
		echo "Failed to bootstrap mise binary at $(MISE)."; \
		exit 1; \
	fi
	@$(MISE) install
	@$(MISE) tasks run install-tools
	@if ! command -v xmllint >/dev/null 2>&1; then \
		echo "Missing required tool: xmllint"; \
		echo "Install libxml2-utils (or equivalent package) and retry."; \
		exit 1; \
	fi
	@mkdir -p $(BUILD_DIR)

install: setup-env ## Install pre-commit hooks
	@$(MAKE) --no-print-directory _install-hooks

install-hooks: setup-env ## (Re-)install pre-commit hooks
	@$(MAKE) --no-print-directory _install-hooks

_install-hooks:
	@$(RUN) pre-commit install
	@$(RUN) pre-commit install --hook-type commit-msg
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

lint: setup-env ## Run all checks via pre-commit
	@echo "Running all checks via pre-commit (LINT_MODE=$(LINT_MODE))..."
	@$(RUN) pre-commit install --install-hooks >/dev/null 2>&1 || true
	@LINT_MODE=$(LINT_MODE) $(RUN) pre-commit run --all-files --color=always

build: setup-env ## Build the project with Gradle
	$(RUN) ./gradlew build

test: setup-env ## Run the test suite with Gradle
	$(RUN) ./gradlew test

clean: ## Remove build artefacts and cache directories
	$(RUN) ./gradlew clean 2>/dev/null || true
	find . -name "*.tmp" -delete 2>/dev/null || true
	rm -rf $(BUILD_DIR)/
