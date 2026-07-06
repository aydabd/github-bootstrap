# =============================================================================
# Environment Setup
# =============================================================================
setup-env: ## Setup selected environment manager (ENV_MANAGER=micromamba|mise|system)
	@set -euo pipefail; $(SETUP_TRACE) \
	case "$(ENV_MANAGER)" in \
		micromamba) \
			if [ -f "$(ENV_STAMP)" ] && $(call mamba_env_exists) 2>/dev/null; then \
				if ! $(MICROMAMBA) run -n $(MAMBA_ENV) -- go version >/dev/null 2>&1; then \
					echo "Go is missing from micromamba environment; refreshing environment..."; \
					$(MICROMAMBA) env update -n $(MAMBA_ENV) -f $(MAMBA_SPEC); \
				fi; \
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
			for tool in pre-commit ec shellcheck shfmt xmllint taplo yamllint markdownlint prettier terraform go; do \
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
