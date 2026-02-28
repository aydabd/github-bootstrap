---
name: testing-integration
description: >
  Integration and E2E testing design. Use this when writing integration tests,
  E2E tests, or deciding what belongs in each test layer.
---

# Skill: Integration & E2E Testing

## Test Pyramid

```
        /  E2E  \        ← few: full system, real environment
       / Integr. \       ← moderate: real components, no network
      /   Unit    \      ← many: fast, isolated, mocked dependencies
```

- **Unit tests** — single function/class, mocked dependencies, milliseconds.
- **Integration tests** — two or more real components, no external network.
- **E2E tests** — compiled binary or deployed service, real user scenarios.

## What Belongs in Integration Tests

- Two or more **real** components working together (no mocks at the boundary).
- Full pipeline execution with real files or data.
- Error propagation across component boundaries.
- File I/O, CLI flag parsing, or configuration loading.

**Do NOT add integration tests for:**

- Single-function logic — use a unit test.
- Flaky external network calls — stub or mock them.

## E2E Test Design

An E2E test exercises the system exactly as a user would:

1. Build/deploy the artifact once; reuse across test cases.
2. Use real configuration, real files, real CLI arguments.
3. Assert on user-visible output (stdout, files, HTTP responses).
4. Clean up all side effects (temp files, test data).

## Corner Cases for Integration & E2E

Before declaring a feature integration-tested, verify:

- **Empty input** — zero items, empty files.
- **Malformed data** — truncated files, wrong types.
- **Large input** — hundreds of items with deep nesting.
- **Permission errors** — unreadable or missing files.
- **Concurrent execution** — two workers processing the same data.
- **Missing configuration** — required env vars or config files absent.

## Requirements → Tests Traceability

Every requirement should map to at least one test:

```
Requirement: "Users can export data as CSV"
├── Unit:        TestCSVFormatter_ValidData_ReturnsCSV
├── Integration: TestExportPipeline_FetchAndFormat_ProducesFile
└── E2E:         TestCLI_ExportCSV_WritesValidFile
```

If a requirement has no test, it is unverified. If a test maps to no
requirement, question whether it adds value.
