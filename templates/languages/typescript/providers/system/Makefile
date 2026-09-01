# =============================================================================
# {{REPOSITORY_NAME}} — Makefile (system)
# =============================================================================

.DEFAULT_GOAL := help
SHELL := /bin/bash

.SUFFIXES:
.DELETE_ON_ERROR:
MAKEFLAGS += --no-builtin-rules

.PHONY: help install install-hooks setup-env quality test build clean verify-makefile

LINT_MODE ?= fix
BUILD_DIR := build

help: ## Show available make targets
	@echo "{{REPOSITORY_NAME}} — Available Commands (system):"
	@echo ""
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "} {targets[++n]=$$1; desc[$$1]=$$2; if (length($$1)>max) max=length($$1)} END {for (i=1; i<=n; i++) printf "  \033[36m%-*s\033[0m %s\n", max, targets[i], desc[targets[i]]}'

setup-env: ## Validate required tools are available on PATH
	@missing=0; \
	for tool in uv python3 shellcheck shfmt xmllint taplo markdownlint prettier npm npx node; do \
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
	@uv sync --locked

install: setup-env ## Install hooks and npm dependencies
	@npm install
	@$(MAKE) --no-print-directory _install-hooks

install-hooks: setup-env ## (Re-)install pre-commit hooks
	@$(MAKE) --no-print-directory _install-hooks

_install-hooks:
	@uv run pre-commit install
	@uv run pre-commit install --hook-type commit-msg
	@for hook in pre-commit commit-msg; do \
		hook_file=".git/hooks/$$hook"; \
		if [ -f "$$hook_file" ] && ! grep -q 'uv-venv-path' "$$hook_file"; then \
			ROOT_DIR="$$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; \
			{ head -1 "$$hook_file"; \
			echo "# uv-venv-path"; \
			echo "export PATH=\"$$ROOT_DIR/.venv/bin:\$$PATH\""; \
			tail -n +2 "$$hook_file"; \
			} > "$$hook_file.tmp" && mv "$$hook_file.tmp" "$$hook_file" && chmod +x "$$hook_file"; \
		fi; \
	done

quality: setup-env ## Run all quality checks via pre-commit
	@echo "Running all checks via pre-commit (LINT_MODE=$(LINT_MODE))..."
	@uv run pre-commit install --install-hooks >/dev/null 2>&1 || true
	@LINT_MODE=$(LINT_MODE) uv run pre-commit run --all-files --color=always

build: setup-env ## Compile TypeScript to JavaScript
	npx tsc

test: setup-env ## Run the test suite
	npm test

clean: ## Remove build artefacts and cache directories
	find . -name "*.tmp" -delete 2>/dev/null || true
	find . -name ".DS_Store" -delete 2>/dev/null || true
	rm -rf $(BUILD_DIR)/ dist/

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
