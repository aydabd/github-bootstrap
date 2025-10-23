.PHONY: help install lint lint-fix test coverage clean

# Default target
help:
	@echo "Available targets:"
	@echo "  make install    - Install dependencies"
	@echo "  make lint       - Run super-linter locally (check only)"
	@echo "  make lint-fix   - Run super-linter locally with auto-fix"
	@echo "  make test       - Run tests"
	@echo "  make coverage   - Run tests with coverage"
	@echo "  make clean      - Clean build artifacts"

# Install dependencies (customize based on your language)
install:
	@echo "Installing dependencies..."
	@echo "Note: Update this target based on your project's language and package manager"
	# Example for Node.js: npm install
	# Example for Python: pip install -r requirements.txt
	# Example for Go: go mod download
	# Example for Ruby: bundle install

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

# Run tests (customize based on your language)
test:
	@echo "Running tests..."
	@echo "Note: Update this target based on your project's testing framework"
	# Example for Node.js: npm test
	# Example for Python: pytest
	# Example for Go: go test ./...
	# Example for Ruby: bundle exec rspec

# Run tests with coverage (customize based on your language)
coverage:
	@echo "Running tests with coverage..."
	@echo "Note: Update this target based on your project's testing framework"
	# Example for Node.js: npm run coverage
	# Example for Python: pytest --cov
	# Example for Go: go test -cover ./...
	# Example for Ruby: bundle exec rspec --coverage

# Clean build artifacts (customize based on your language)
clean:
	@echo "Cleaning build artifacts..."
	@echo "Note: Update this target based on your project's build output"
	# Example: rm -rf node_modules dist build *.pyc __pycache__ .coverage
