# GitHub Copilot Instructions

## Code Generation Standards

- SOLID principles mandatory
- Generate testable code only
- Include type annotations
- Use clear naming conventions
- Follow language best practices
- Production-ready code

## Formatting Rules

- Programming languages: 4 spaces
- Config files (YAML/JSON): 2 spaces
- Remove trailing whitespace
- Consistent indentation
- Follow project linter rules
- Self-documenting code

## Testing Requirements

- Generate unit tests
- Include test fixtures
- Use appropriate assertions
- Mock external services
- Test happy paths
- Test error paths

## Architecture Patterns

- Single responsibility per class
- Depend on abstractions
- Inject dependencies
- Separate concerns
- Composition over inheritance
- Interface-based design

## Documentation

- Add docstrings to functions
- Document complex logic only
- Include type hints
- Explain non-obvious code
- Keep comments current
- Code should explain itself

## Dependencies

- Minimize external dependencies
- Use standard library first
- Abstract third-party code
- Version pin all dependencies
- Document dependency rationale
- Review dependency security

## Error Handling

- Handle errors explicitly
- Use appropriate exceptions
- Don't silently fail
- Log errors properly
- Clean up resources
- Validate inputs early

## Security

- Validate all inputs
- Sanitize outputs
- Use parameterized queries
- Never hardcode secrets
- Follow security best practices
- Principle of least privilege
