# {{REPOSITORY_NAME}}

[![Lint](https://github.com/{{REPOSITORY_OWNER}}/{{REPOSITORY_NAME}}/actions/workflows/lint.yml/badge.svg)](https://github.com/{{REPOSITORY_OWNER}}/{{REPOSITORY_NAME}}/actions/workflows/lint.yml)

## Overview

Brief project description following SOLID principles, TDD, and DDD architecture patterns.

## Architecture

This project follows:

- **SOLID principles** for maintainable code
- **Test-Driven Development** (TDD) for reliability
- **Domain-Driven Design** (DDD) for clear business logic
- **Type-safe** implementation
- **Dependency injection** for testability

## Development

### Prerequisites

List required tools and versions here.

### Setup

```bash
git clone <repository-url>
cd <repository-name>

# Install dependencies
make install
```

### Running Tests

```bash
# Run all tests
make test

# Run with coverage
make coverage
```

### Linting

```bash
# Run linting locally (auto-fix mode)
make lint

# Run linting in check-only mode (CI-equivalent)
LINT_MODE=check make lint
```

The repository includes a GitHub lint workflow backed by pre-commit for
consistent code quality:

- **Automatic validation** on pull requests and pushes
- **Language-agnostic linting** for Markdown, YAML, JSON, XML, and EditorConfig
- **Language-specific checks** from template-specific `.pre-commit-config.yaml`
- **Local linting** via `make lint` in a micromamba-managed environment

## Code Standards

- **Indentation**: 4 spaces (code), 2 spaces (YAML/JSON)
- **Linting**: Enforced via pre-commit hooks
- **Formatting**: Autoformat before commit
- **Type safety**: Strictly enforced
- **No trailing whitespace**

## Contributing

1. Create feature branch from `main`
2. Write tests first (TDD)
3. Implement feature
4. Ensure all tests pass
5. Run linter and formatter
6. Submit PR (requires 2 approvals)

See [CONTRIBUTING.md](CONTRIBUTING.md) and [CODEOWNERS](.github/CODEOWNERS) for details.

## Security

To report a vulnerability, please see [SECURITY.md](SECURITY.md).

## Testing Philosophy

- All code must be testable
- Unit tests for all modules
- Integration tests for components
- Test fixtures separated by module
- Minimum 80% coverage

## License

See LICENSE file for details.
