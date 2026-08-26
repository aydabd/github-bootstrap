# =============================================================================
# Quality checks
# =============================================================================
# Pre-commit is the single source of truth for ALL quality checks.
# LINT_MODE=fix  -> auto-fix formatting (default for local development)
# LINT_MODE=check -> check-only, fail on violations (CI)
quality: setup-env ## Run all quality checks via pre-commit (ENV_MANAGER=micromamba|mise|system)
	@echo "Running quality checks via pre-commit (ENV_MANAGER=$(ENV_MANAGER), LINT_MODE=$(LINT_MODE))..."
	@$(CMD_ECHO) "+ $(RUN) pre-commit install --install-hooks"
	@$(RUN) pre-commit install --install-hooks >/dev/null 2>&1 || true
	@$(CMD_ECHO) "+ LINT_MODE=$(LINT_MODE) $(RUN) pre-commit run --all-files --color=always"
	@LINT_MODE=$(LINT_MODE) $(RUN) pre-commit run --all-files --color=always
