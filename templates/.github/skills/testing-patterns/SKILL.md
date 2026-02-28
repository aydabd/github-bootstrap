---
name: testing-patterns
description: >
  Test implementation patterns. Use this when writing tests — table-driven tests,
  mocking, fixtures, assertions, and parallel execution.
---

# Skill: Testing Patterns

## Table-Driven Tests

Prefer table-driven tests when testing the same function across multiple scenarios:

```
tests := []struct {
    name    string
    input   InputType
    want    OutputType
    wantErr bool
}{
    {"valid input", validInput, expectedOutput, false},
    {"empty input returns error", emptyInput, zero, true},
    {"boundary value", boundaryInput, boundaryOutput, false},
}
for _, tt := range tests {
    t.Run(tt.name, func(t *testing.T) {
        got, err := FunctionUnderTest(tt.input)
        // assert based on tt.wantErr, tt.want
    })
}
```

## Mocking External Dependencies

Mock at the **interface** boundary, not the implementation:

```
// Define a small interface for the dependency
type DataStore interface {
    Get(key string) (string, error)
}

// Create a mock that implements the interface
type mockStore struct {
    data map[string]string
    err  error
}
```

Keep mocks in the same test file that uses them. Never mock what you own — test
your own code with real implementations when possible.

## Test Fixture Setup

Extract repetitive setup into named helper functions:

- Mark helpers with the language's test-helper annotation (e.g. `t.Helper()` in Go).
- Return fully configured objects — don't force tests to build state step by step.
- Use temporary directories for file I/O tests; clean up automatically.

## Assertions

Use assertion libraries for readable failure messages:

- **Equality**: `assertEqual(expected, actual)` — value comparison.
- **Error expected**: `assertError(err)` — confirms failure path.
- **No error**: `assertNoError(err)` — confirms success path.
- **Contains**: `assertContains(haystack, needle)` — partial match.
- **Fatal vs soft**: Use fatal assertions when subsequent checks are meaningless
  after a failure; use soft assertions when all failures should be reported.

## Test Isolation

- Each test must be independently runnable — no ordering dependencies.
- Avoid shared mutable state between tests.
- Use parallel execution for independent tests to catch race conditions.
- Clean up all resources created during tests (files, connections, goroutines).
