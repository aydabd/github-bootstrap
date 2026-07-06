# =============================================================================
# {{REPOSITORY_NAME}} — Makefile (mise)
# =============================================================================

.DEFAULT_GOAL := help
SHELL := /bin/bash

.SUFFIXES:
.DELETE_ON_ERROR:
MAKEFLAGS += --no-builtin-rules

.PHONY: help install install-hooks setup-env lint test coverage clean verify-makefile

LINT_MODE ?= fix
BUILD_DIR := build
MISE ?= $(CURDIR)/.provider/bin/mise
RUN := $(MISE) exec --

help: ## Show available make targets
	@echo "{{REPOSITORY_NAME}} — Available Commands (mise):"
	@echo ""
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "} {targets[++n]=$$1; desc[$$1]=$$2; if (length($$1)>max) max=length($$1)} END {for (i=1; i<=n; i++) printf "  \033[36m%-*s\033[0m %s\n", max, targets[i], desc[targets[i]]}'

setup-env: ## Setup isolated environment with mise
	@if [ ! -x "$(MISE)" ]; then \
		echo "Bootstrapping project-local mise binary..."; \
		bash scripts/bootstrap-provider-binary.sh mise "$(MISE)"; \
	fi
	@if [ ! -x "$(MISE)" ]; then \
		echo "Failed to bootstrap mise binary at $(MISE)."; \
		exit 1; \
	fi
	@PATH="$(dir $(MISE)):$$PATH" $(MISE) install
	@PATH="$(dir $(MISE)):$$PATH" $(MISE) tasks run install-tools
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

test: setup-env ## Run the test suite
	$(RUN) pytest tests/ -v

coverage: setup-env ## Run tests with coverage report
	$(RUN) pytest tests/ \
		--cov=src \
		--cov-report=term-missing

clean: ## Remove build artefacts and cache directories
	find . -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name '.pytest_cache' -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name '.ruff_cache' -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name '.mypy_cache' -exec rm -rf {} + 2>/dev/null || true
	find . -name ".DS_Store" -delete 2>/dev/null || true
	find . -name "*.tmp" -delete 2>/dev/null || true
	rm -rf htmlcov/ .coverage coverage.xml $(BUILD_DIR)/

verify-makefile: ## Validate make target metadata and help coverage
	@set -euo pipefail; \
	documented_targets="$$(grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sed -E 's/:.*$$//')"; \
	defined_targets="$$(grep -hE '^[a-zA-Z_-]+:' $(MAKEFILE_LIST) | sed -E 's/:.*$$//' | sort -u)"; \
	fail=0; \
	for target in $$defined_targets; do \
		case "$$target" in _*) continue ;; esac; \
		if ! printf '%s\n' "$$documented_targets" | grep -qx "$$target"; then \
			echo "Missing help metadata (##) for target: $$target"; \
			fail=1; \
		fi; \
	done; \
	for target in $$documented_targets; do \
		if ! printf '%s\n' "$$defined_targets" | grep -qx "$$target"; then \
			echo "Help metadata references undefined target: $$target"; \
			fail=1; \
		fi; \
	done; \
	duplicates="$$(printf '%s\n' "$$documented_targets" | sort | uniq -d)"; \
	if [ -n "$$duplicates" ]; then \
		echo "Duplicate help target entries found:"; \
		echo "$$duplicates"; \
		fail=1; \
	fi; \
	if [ "$$fail" -ne 0 ]; then \
		exit 1; \
	fi; \
	echo "Makefile metadata checks passed"
