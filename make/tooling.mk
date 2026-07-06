# =============================================================================
# Tooling Updates (non-Dependabot-managed)
# =============================================================================
tooling-updater-build: setup-env ## Build tooling updater CLI binary from latest source
	@mkdir -p $(BUILD_DIR)/bin
	@$(RUN) env CGO_ENABLED=0 go build -o $(TOOLING_UPDATER_BIN) ./tools/cmd/tooling-updater

tooling-update-repo: tooling-updater-build ## Update repo tooling pins (pre-commit, mise/micromamba, lint toolchain)
	@$(RUN) $(TOOLING_UPDATER_BIN) --scope repo --updaters all

tooling-update-templates: tooling-updater-build ## Update template tooling pins for generated repositories
	@$(RUN) $(TOOLING_UPDATER_BIN) --scope templates --updaters all

tooling-update-all: tooling-updater-build ## Update repo + template tooling pins
	@$(RUN) $(TOOLING_UPDATER_BIN) --scope all --updaters all

tooling-update-micromamba: tooling-updater-build ## Update micromamba-managed tooling (env files + provider binary pins)
	@$(RUN) $(TOOLING_UPDATER_BIN) --scope all --updaters micromamba

tooling-update-mise: tooling-updater-build ## Update mise-managed tooling (mise.toml files + provider binary pins)
	@$(RUN) $(TOOLING_UPDATER_BIN) --scope all --updaters mise

tooling-update-system: tooling-updater-build ## Run system updater (reserved no-op updater for explicit extension point)
	@$(RUN) $(TOOLING_UPDATER_BIN) --scope all --updaters system

tooling-update-precommit: tooling-updater-build ## Update pre-commit hook revisions for repo and templates
	@$(RUN) $(TOOLING_UPDATER_BIN) --scope all --updaters pre-commit

tooling-verify: tooling-updater-build ## Verify updater layout assumptions and run updater unit tests
	@$(RUN) $(TOOLING_UPDATER_BIN) --verify-only
	@$(RUN) env CGO_ENABLED=0 go test ./tools/...

render-precommit: ## Regenerate template pre-commit configs from snippet packs
	@$(RUN) go run ./tools/cmd/precommit-renderer --base templates/languages/agnostic/pre-commit-snippets/base.tmpl --snippets-root templates/languages --languages language-agnostic-only --output templates/languages/agnostic/.pre-commit-config.yaml
	@$(RUN) go run ./tools/cmd/precommit-renderer --base templates/languages/agnostic/pre-commit-snippets/base.tmpl --snippets-root templates/languages --languages golang --output templates/languages/golang/.pre-commit-config.yaml
	@$(RUN) go run ./tools/cmd/precommit-renderer --base templates/languages/agnostic/pre-commit-snippets/base.tmpl --snippets-root templates/languages --languages python --output templates/languages/python/.pre-commit-config.yaml
	@$(RUN) go run ./tools/cmd/precommit-renderer --base templates/languages/agnostic/pre-commit-snippets/base.tmpl --snippets-root templates/languages --languages typescript --output templates/languages/typescript/.pre-commit-config.yaml
	@$(RUN) go run ./tools/cmd/precommit-renderer --base templates/languages/agnostic/pre-commit-snippets/base.tmpl --snippets-root templates/languages --languages java --output templates/languages/java/.pre-commit-config.yaml
