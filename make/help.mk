# =============================================================================
# Help and Metadata Validation
# =============================================================================
help: ## Show available make targets
	@echo "GitHub Bootstrap — Available Commands:"
	@echo ""
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "} { \
			targets[++n] = $$1; \
			desc[$$1] = $$2; \
			if (length($$1) > max) max = length($$1); \
		} END { \
			groups[1] = "Core"; \
			groups[2] = "Environment Setup"; \
			groups[3] = "Quality and Testing"; \
			groups[4] = "Tooling Updates"; \
			groups[5] = "Template Generation"; \
			groups[6] = "Maintenance"; \
			groups[7] = "Other"; \
			for (g = 1; g <= 7; g++) { \
				printed = 0; \
				for (i = 1; i <= n; i++) { \
					t = targets[i]; \
					if (category(t) == groups[g]) { \
						if (printed == 0) { \
							print groups[g] ":"; \
							printed = 1; \
						} \
						printf "  \033[36m%-*s\033[0m %s\n", max, t, desc[t]; \
					} \
				} \
				if (printed == 1) print ""; \
			} \
			print "Options:"; \
			print "  ENV_MANAGER    micromamba | mise | system (default: micromamba)"; \
			print "  LINT_MODE      fix | check (default: fix)"; \
			print "  SHOW_COMMANDS  1 | 0 (default: 1)"; \
			print "  TEST_PRESET    none | api-default | terraform-default | api-no-repo-settings | terraform-no-repo-settings | api-all-languages | terraform-all-languages (default: none)"; \
			print "  TEST_REPO_NAME Test repo base name before timestamp suffix (default: automated-test)"; \
			print "  TEST_LANGUAGES language-agnostic-only | all | csv list (default: language-agnostic-only)"; \
			print "  TEST_TARGET_WORKFLOW create-repository.yml | terraform-create-repository.yml (default: create-repository.yml)"; \
			print "  TEST_TARGET_REF Branch/tag ref for target workflow (default: main)"; \
			print "  TEST_LOCAL_SETUP_REPO_NAME Local setup test repo base name (default: scripts)"; \
			print "  TEST_LOCAL_SETUP_VISIBILITY public | private | internal (default: public)"; \
			print "  TEST_LOCAL_SETUP_RULESET_PROFILE minimal | default | coderabbit (default: minimal)"; \
			print "  TEST_LOCAL_SETUP_REF Branch/tag ref for local setup test workflow (default: main)"; \
			print "  cleanup_after_test Always true for make test commands"; \
		} \
		function category(name) { \
			if (name == "help") return "Core"; \
			if (name ~ /^(setup-env|install|install-hooks)$$/) return "Environment Setup"; \
			if (name ~ /^(lint|test($$|-))/) return "Quality and Testing"; \
			if (name ~ /^tooling-/) return "Tooling Updates"; \
			if (name ~ /^render-/) return "Template Generation"; \
			if (name ~ /^(clean|verify-makefile|verify-template-makefiles)$$/) return "Maintenance"; \
			return "Other"; \
		}'

verify-makefile: ## Validate make target metadata and help coverage
	@set -euo pipefail; \
	documented_targets="$$(grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sed -E 's/:.*$$//')"; \
	defined_targets="$$(grep -hE '^[a-zA-Z_-]+:' $(MAKEFILE_LIST) | sed -E 's/:.*$$//' | sort -u)"; \
	fail=0; \
	for target in $(PUBLIC_TARGETS); do \
		if ! printf '%s\n' "$$documented_targets" | grep -qx "$$target"; then \
			echo "Missing help metadata (##) for public target: $$target"; \
			fail=1; \
		fi; \
		if ! printf '%s\n' "$$defined_targets" | grep -qx "$$target"; then \
			echo "Public target list references undefined target: $$target"; \
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
