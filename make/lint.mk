# =============================================================================
# Quality checks
# =============================================================================
# Pre-commit is the single source of truth for ALL quality checks.
# LINT_MODE=fix  -> auto-fix formatting (default for local development)
# LINT_MODE=check -> check-only, fail on violations (CI)
quality: setup-env quality-contract-tests quality-go-tests ## Run all quality checks and deterministic tests (ENV_MANAGER=micromamba|mise|system, LINT_MODE=fix|check)
	@echo "Running quality checks via pre-commit (ENV_MANAGER=$(ENV_MANAGER), LINT_MODE=$(LINT_MODE))..."
	@$(CMD_ECHO) "+ $(RUN) pre-commit install --install-hooks"
	@$(RUN) pre-commit install --install-hooks >/dev/null 2>&1 || true
	@$(CMD_ECHO) "+ LINT_MODE=$(LINT_MODE) $(RUN) pre-commit run --all-files --color=always"
	@LINT_MODE=$(LINT_MODE) $(RUN) pre-commit run --all-files --color=always

# Live E2E remains explicit via scripts/github-setup/test-local-setup-scripts.sh.
quality-contract-tests: ## Run deterministic shell contract tests; live E2E remains explicit
	@$(CMD_ECHO) "+ bash scripts/run-contract-tests.sh"
	@bash scripts/run-contract-tests.sh

quality-go-tests: ## Run Go tests regardless of changed-file filters
	@$(CMD_ECHO) "+ $(RUN) go test ./tools/..."
	@CGO_ENABLED=0 $(RUN) go test ./tools/...

quality-actions: setup-env ## Opt-in GitHub Actions linting with actionlint and zizmor
	@$(CMD_ECHO) "+ $(RUN) pre-commit run lint-actions --all-files --color=always"
	@$(RUN) pre-commit run lint-actions --all-files --color=always
