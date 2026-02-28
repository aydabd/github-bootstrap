---
name: development-workflow
description: >
  Requirements-to-implementation workflow. Use this when connecting requirements
  to design, implementation, testing, and delivery.
---

# Skill: Development Workflow

## Requirements → Implementation Flow

```text
Requirement → Design → Implementation → Unit Tests → Integration Tests → E2E → Review → Merge
```

Every feature follows this flow. No step is skipped.

## Handling Requirements

1. **Clarify** — confirm acceptance criteria before writing code.
2. **Break down** — split into independently testable units.
3. **Trace** — each requirement maps to at least one test.
4. **Verify** — acceptance criteria become assertions in tests.

## Connecting Requirements to Tests

| Requirement type      | Test layer         | Example                             |
| --------------------- | ------------------ | ----------------------------------- |
| Business rule         | Unit test          | Input validation, calculation logic |
| Component interaction | Integration test   | Service calls repository correctly  |
| User-facing behavior  | E2E test           | CLI outputs expected result         |
| Error handling        | Unit + Integration | Graceful failure on bad input       |
| Performance           | Benchmark          | Response time under load            |

## Implementation Checklist

Before starting implementation:

- [ ] Requirements are clear and unambiguous
- [ ] Acceptance criteria are defined
- [ ] Test cases are identified (before writing code)
- [ ] Dependencies are identified and abstracted

During implementation:

- [ ] Write tests first or alongside code (TDD/TLD)
- [ ] Each function has a single responsibility
- [ ] Error paths are handled explicitly
- [ ] Dependencies are injected, not hardcoded

Before submitting for review:

- [ ] All tests pass locally
- [ ] Coverage meets project threshold
- [ ] Linting passes with no warnings
- [ ] Documentation updated (if public API changed)
- [ ] No TODO/FIXME left in production code

## Code Review Focus

Reviewers should verify:

1. Does the code match the requirement?
2. Are edge cases tested?
3. Is error handling complete?
4. Are dependencies properly abstracted?
5. Is the code readable without explanation?
