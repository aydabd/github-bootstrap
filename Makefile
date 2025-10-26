.PHONY: help lint lint-fix test clean

# Default target
help:
	@echo "Available targets:"
	@echo "  make lint       - Run super-linter locally (check only)"
	@echo "  make lint-fix   - Run super-linter locally with auto-fix"
	@echo "  make test       - Run repository creation tests"
	@echo "  make clean      - Clean temporary files"

# Run super-linter locally (check only mode)
lint:
	@echo "Running super-linter in check mode..."
	@docker pull github/super-linter:latest
	@docker run \
		--rm \
		-e RUN_LOCAL=true \
		-e DEFAULT_BRANCH=main \
		-e VALIDATE_ALL_CODEBASE=true \
		-e FIX_MODE=false \
		-e LOG_LEVEL=NOTICE \
		--env-file .super-linter.env \
		-v $(PWD):/tmp/lint \
		github/super-linter:latest

# Run super-linter locally with auto-fix
lint-fix:
	@echo "Running super-linter in fix mode..."
	@docker pull github/super-linter:latest
	@docker run \
		--rm \
		-e RUN_LOCAL=true \
		-e DEFAULT_BRANCH=main \
		-e VALIDATE_ALL_CODEBASE=true \
		-e FIX_MODE=true \
		-e LOG_LEVEL=NOTICE \
		--env-file .super-linter.env \
		-v $(PWD):/tmp/lint \
		github/super-linter:latest
	@echo "Auto-fixes applied. Review changes with 'git diff'"

# Run repository creation tests
test:
	@echo "Running repository creation tests..."
	@gh workflow run test-repository-creation.yml \
		--field test_repo_name="automated-test" \
		--field primary_language="multi-language" \
		--field cleanup_after_test="true" \
		--field wait_time_minutes="5"
	@echo "Test triggered. Check: gh run list --workflow=test-repository-creation.yml"

# Clean temporary files
clean:
	@echo "Cleaning temporary files..."
	@find . -name "*.tmp" -delete
	@find . -name ".DS_Store" -delete
	@echo "Cleanup complete"