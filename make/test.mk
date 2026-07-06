# =============================================================================
# Testing
# =============================================================================

TEST_REPO_NAME ?= automated-test
TEST_PRESET ?= none
TEST_LANGUAGES ?= language-agnostic-only
TEST_TARGET_WORKFLOW ?= create-repository.yml
TEST_TARGET_REF ?= main

test: ## Trigger repository creation tests via GitHub Actions
	@echo "Running repository creation tests..."
	@$(CMD_ECHO) "+ gh workflow run test-repository-creation.yml --field test_repo_name=$(TEST_REPO_NAME) --field preset=$(TEST_PRESET) --field languages=$(TEST_LANGUAGES) --field target_workflow=$(TEST_TARGET_WORKFLOW) --field target_ref=$(TEST_TARGET_REF) --field cleanup_after_test=true"
	@gh workflow run test-repository-creation.yml \
		--field test_repo_name="$(TEST_REPO_NAME)" \
		--field preset="$(TEST_PRESET)" \
		--field languages="$(TEST_LANGUAGES)" \
		--field target_workflow="$(TEST_TARGET_WORKFLOW)" \
		--field target_ref="$(TEST_TARGET_REF)" \
		--field cleanup_after_test="true"
	@echo "Test triggered. Check: gh run list --workflow=test-repository-creation.yml"

test-api-default: ## Trigger test workflow with preset=api-default
	@$(MAKE) --no-print-directory test TEST_PRESET=api-default

test-terraform-default: ## Trigger test workflow with preset=terraform-default
	@$(MAKE) --no-print-directory test TEST_PRESET=terraform-default

test-api-no-repo-settings: ## Trigger test workflow with preset=api-no-repo-settings
	@$(MAKE) --no-print-directory test TEST_PRESET=api-no-repo-settings

test-terraform-no-repo-settings: ## Trigger test workflow with preset=terraform-no-repo-settings
	@$(MAKE) --no-print-directory test TEST_PRESET=terraform-no-repo-settings

test-api-all-languages: ## Trigger test workflow with preset=api-all-languages
	@$(MAKE) --no-print-directory test TEST_PRESET=api-all-languages

test-terraform-all-languages: ## Trigger test workflow with preset=terraform-all-languages
	@$(MAKE) --no-print-directory test TEST_PRESET=terraform-all-languages
