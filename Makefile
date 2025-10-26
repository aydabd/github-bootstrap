.PHONY: help lint lint-fix test clean

# Default target
help:
	@echo "Available targets:"
	@echo "  make lint       - Run super-linter locally (check only)"
	@echo "  make lint-fix   - Run super-linter locally with auto-fix"
	@echo "  make test       - Run repository creation tests"
	@echo "  make clean      - Clean temporary files"

# Lint the codebase using Super-Linter
lint:
	@echo "Running Super-Linter..."
	docker run --rm \
		--platform linux/amd64 \
		--env-file .super-linter.env \
		-e PARALLEL_SHELL=/bin/bash \
		-e RUN_LOCAL=true \
		-e DEFAULT_BRANCH=main \
		-e DEFAULT_WORKSPACE=/tmp/lint \
		-v "$(PWD):/tmp/lint:ro" \
		ghcr.io/super-linter/super-linter:v8.2.1

# Lint the codebase using Super-Linter with auto-fix
lint-fix:
	@echo "Running Super-Linter with auto-fix..."
	docker run --rm \
		--platform linux/amd64 \
		--env-file .super-linter.env \
		-e PARALLEL_SHELL=/bin/bash \
		-e RUN_LOCAL=true \
		-e DEFAULT_BRANCH=main \
		-e DEFAULT_WORKSPACE=/tmp/lint \
		-v "$(PWD):/tmp/lint" \
		ghcr.io/super-linter/super-linter:v8.2.1

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