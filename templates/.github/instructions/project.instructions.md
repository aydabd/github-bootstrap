---
applyTo: "**"
---

# Project — AI Agent Instructions

> **Single source of truth** for all AI coding agents (GitHub Copilot, Claude Code,
> OpenAI Codex, Cursor, and others).
> Edit **only this file** to update instructions across every agent.

## Golden Rules

1. **Simplicity** — simplest working solution wins.
2. **SOLID** — single responsibility, dependency injection, interface-based design.
3. **Testability** — every module must be independently testable.
4. **Long-term** — code must be maintainable for years.
5. **Type safety** — strict typing enforced.

## Code Style

- Follow language idioms and standard formatting tools.
- Keep functions small and focused (max 50 lines).
- Use meaningful variable names; avoid abbreviations.
- Add comments only when code is not self-explanatory (explain _why_, not _what_).
- Handle errors explicitly — never ignore them.
- Write tests for new functionality.
- **Formatting**: 4 spaces for code, 2 spaces for YAML/JSON.
- No trailing whitespace.

## Testing

- Write tests alongside new code (TDD).
- Use table-driven tests where applicable.
- Mock external dependencies.
- Test error cases, not just happy paths.
- Minimum 80% coverage.

## Documentation

Update docs only when:

- Public interface changes.
- Setup process changes.
- New configuration options are added.

Do **not** update docs for internal refactoring, bug fixes, or performance improvements.

## Skills

Specialised agent skills live in `.github/skills/`.
Each skill directory contains a `SKILL.md` (≤ 100 lines) covering one focused topic.

| Skill directory        | Purpose                                                 |
| ---------------------- | ------------------------------------------------------- |
| `testing-strategy`     | Testing philosophy, value-driven approach, corner cases |
| `testing-patterns`     | Table-driven tests, mocking, fixtures, assertions       |
| `testing-integration`  | Integration & E2E testing, test pyramid, traceability   |
| `development-workflow` | Requirements → implementation → testing → review flow   |

Add project-specific skills as the codebase grows.

## What to Avoid

- Features added "just in case"
- Complex abstractions or inheritance hierarchies
- Reflection unless absolutely necessary
- Magic numbers (use named constants)
- Global state
- New dependencies without strong justification
- Premature optimization
- Hardcoded secrets or paths
- Silently ignoring errors
- Placeholder or TODO code in production
