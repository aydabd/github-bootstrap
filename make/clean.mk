# =============================================================================
# Maintenance
# =============================================================================
verify-template-makefiles: ## Run verify-makefile for all template provider Makefiles
	@set -euo pipefail; \
	template_makefiles="$$(find templates/languages -path '*/providers/*/Makefile' -type f | sort)"; \
	if [ -z "$$template_makefiles" ]; then \
		echo "No template Makefiles found under templates/languages"; \
		exit 1; \
	fi; \
	count=0; \
	for file in $$template_makefiles; do \
		count=$$((count + 1)); \
		echo "[verify] $$file"; \
		$(MAKE) --no-print-directory -f "$$file" verify-makefile; \
	done; \
	echo "Verified $$count template Makefiles"

clean: ## Remove build artefacts and cache directories
	find . -name "*.tmp" -delete 2>/dev/null || true
	rm -rf $(BUILD_DIR)/
	@find . -name ".DS_Store" -delete
	@echo "Cleanup complete"
