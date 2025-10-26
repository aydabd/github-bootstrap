# Agent Instructions

## Core Principles

- SOLID principles mandatory
- Test-driven development (TDD)
- Domain-driven design (DDD)
- Everything must be testable
- Type-safe code required
- Language-agnostic approach

## Code Standards

**Formatting**

- 4 spaces for code
- 2 spaces for YAML/JSON
- No trailing whitespace
- Consistent naming conventions
- Follow language idioms

**Quality**

- Lint before commit
- ### Autoformat
- Self-documenting names
- Clear module boundaries
- Minimal comments (code explains itself)

## Testing Requirements

- Unit tests for all modules
- Integration tests for components
- Mocks/fixtures in separate files
- Test setup/teardown in conftest.py
- Minimum 80% coverage
- Test edge cases and errors

## SOLID Principles

**Single Responsibility**

- One reason to change
- Focused modules

**Open/Closed**

- Open for extension
- Closed for modification

**Liskov Substitution**

- Subtypes must be substitutable
- Maintain contracts

**Interface Segregation**

- Small, focused interfaces
- No fat interfaces

**Dependency Inversion**

- Depend on abstractions
- Inject dependencies

## Architecture Patterns

- Use dependency injection
- Abstract external services
- Separate concerns clearly
- Prefer composition over inheritance
- Keep dependencies minimal

## File Organization

- Modular structure
- Constants in dedicated files
- Configuration externalized
- Clear import hierarchy
- Separate domain/infrastructure

## Documentation

- Docstrings for public APIs
- Inline docs for complex logic
- Readme per major module
- Record architecture decisions
- Document non-obvious code

## Review Checklist

- [ ] SOLID principles followed
- [ ] All code testable
- [ ] Tests included and passing
- [ ] Linting passed
- [ ] Type hints/annotations present
- [ ] Dependencies justified
- [ ] No trailing whitespace
- [ ] Proper formatting
