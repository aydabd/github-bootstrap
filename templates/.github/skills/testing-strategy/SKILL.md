---
name: testing-strategy
description: >
  Testing philosophy and strategy. Use this when deciding what to test,
  naming tests, or identifying corner cases.
---

# Skill: Testing Strategy

## Testing Mindset

- **Think like an adversary** — imagine how the code could break and test those paths.
- **Value over coverage** — a test that proves real behavior beats a metric-inflating test.
  Never write a test that cannot fail in a meaningful way.
- **Readable by anyone** — test names and body must tell a complete story. A failing test
  must explain the problem without requiring a debugger.

## When to Add a Test

Add a test only when it satisfies at least ONE of:

1. It catches a real bug that could reach production.
2. It documents a non-obvious contract (e.g. "returns empty list, never null").
3. It guards a regression that has already occurred.
4. It validates the interaction between two real components.

**Do NOT add tests for:**

- Trivial getters/setters with no logic.
- Behaviour already fully covered by an existing test.
- Happy-path-only tests when edge cases exist and are untested.
- Tests that always pass regardless of implementation.

## Test Case Naming

Use the format `TestUnit_Scenario_ExpectedOutcome`:

```text
TestParseConfig_MissingRequiredField_ReturnsError
TestParseConfig_ValidInput_ReturnsParsedResult
```

Sub-tests use plain, readable English:

```text
"missing required field returns error"
"valid input with 3 items succeeds"
```

## Anatomy of a Good Test

1. **Arrange** — set up inputs and dependencies clearly; avoid hidden shared state.
2. **Act** — single call to the unit under test.
3. **Assert** — check the outcome and produce a message that explains the failure.

Keep each test focused on **one behaviour**. When multiple scenarios exist, use
table rows rather than separate functions.

## Corner Cases Checklist

Before marking a feature tested, ask:

- What happens with a nil/null/zero/empty input?
- What happens at the boundary (first item, last item, exactly at a limit)?
- What happens when a dependency fails halfway through?
- What happens when the same operation runs concurrently?
- What happens with the largest valid input?
- What happens when required configuration is missing?
