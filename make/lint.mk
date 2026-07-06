# =============================================================================
# Linting
# =============================================================================
# Pre-commit is the single source of truth for ALL quality checks.
# LINT_MODE=fix  -> auto-fix formatting (default for local development)
# LINT_MODE=check -> check-only, fail on violations (CI)
lint: setup-env ## Run all checks via pre-commit (LINT_MODE=fix|check)
	@echo "Running all checks via pre-commit (LINT_MODE=$(LINT_MODE))..."
	@$(CMD_ECHO) "+ $(RUN) pre-commit install --install-hooks"
	@$(RUN) pre-commit install --install-hooks >/dev/null 2>&1 || true
	@$(CMD_ECHO) "+ LINT_MODE=$(LINT_MODE) $(RUN) pre-commit run --all-files --color=always"
	@LINT_MODE=$(LINT_MODE) $(RUN) pre-commit run --all-files --color=always
