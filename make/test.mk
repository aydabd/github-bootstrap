# =============================================================================
# Testing
# =============================================================================

TEST_REPO_NAME ?= automated-test
TEST_PRESET ?= none
TEST_LANGUAGES ?= language-agnostic-only
TEST_TARGET_WORKFLOW ?= create-repository.yml
TEST_TARGET_REF ?= main
TEST_LOCAL_SETUP_REPO_NAME ?= scripts
TEST_LOCAL_SETUP_VISIBILITY ?= public
TEST_LOCAL_SETUP_RULESET_PROFILE ?= minimal
TEST_LOCAL_SETUP_REF ?= main

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

test-centralized-monorepo: ## Trigger isolated centralized monorepo E2E (preserves repositories)
	@echo "Running centralized monorepo E2E workflow..."
	@$(CMD_ECHO) "+ gh workflow run test-repository-creation.yml --field preset=centralized-monorepo --field languages=all --field cleanup_after_test=false --field client_id=<e2e-provisioner-client-id> --field app_owner=<e2e-app-owner>"
	@PROVISIONER_APP_CLIENT_ID="$$(gh variable get BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_ID --env e2e --json value --jq .value)" && \
	E2E_APP_OWNER="$$(gh variable get BOOTSTRAP_E2E_APP_OWNER --env e2e --json value --jq .value)" && \
	gh workflow run test-repository-creation.yml \
		--field preset="centralized-monorepo" \
		--field languages="all" \
		--field cleanup_after_test="false" \
		--field client_id="$$PROVISIONER_APP_CLIENT_ID" \
		--field app_owner="$$E2E_APP_OWNER"
	@echo "Test triggered. Check: gh run list --workflow=test-repository-creation.yml"

test-local-setup-scripts: ## Trigger live E2E workflow for local GitHub setup scripts
	@echo "Running local setup script E2E workflow..."
	@$(CMD_ECHO) "+ gh workflow run test-local-setup-scripts.yml --ref $(TEST_LOCAL_SETUP_REF) --field test_repo_name=$(TEST_LOCAL_SETUP_REPO_NAME) --field visibility=$(TEST_LOCAL_SETUP_VISIBILITY) --field ruleset_profile=$(TEST_LOCAL_SETUP_RULESET_PROFILE) --field cleanup_after_test=true"
	@gh workflow run test-local-setup-scripts.yml \
		--ref "$(TEST_LOCAL_SETUP_REF)" \
		--field test_repo_name="$(TEST_LOCAL_SETUP_REPO_NAME)" \
		--field visibility="$(TEST_LOCAL_SETUP_VISIBILITY)" \
		--field ruleset_profile="$(TEST_LOCAL_SETUP_RULESET_PROFILE)" \
		--field cleanup_after_test="true"
	@echo "Test triggered. Check: gh run list --workflow=test-local-setup-scripts.yml"
