---
name: test-log-triage
description: Use when a unit, integration, lint, Playwright, or make check produces failures, skips, inconsistent results, or a long report.
---

# Test Log Triage

Use this skill whenever a `make`, Vitest, Playwright, lint, or E2E command
produces long output or an unexpected result. Prefer report artifacts and
targeted searches over reading full terminal logs.

## Required triage decision

Classify each failure before changing code or selecting new roadmap work:

1. Product defect — the implementation violates the requirement.
2. Test defect — the assertion, fixture, or test setup is wrong.
3. Fixture/state pollution — another test changed shared data or identity
   state; fix ownership/isolation, not the product behavior.
4. Infrastructure failure — Docker, database, browser, or dependency startup.
5. Genuine flake — the same test changes outcome on an unchanged, isolated
   environment after the first four causes are excluded.

Never convert a failure into green by adding retries, `test.skip`,
`expect(true)`, or a conditional pass. Required suites must report zero
unexpected skips. Record the classification and evidence in the related
GitHub issue or PR.

## Test-pyramid placement

- Unit: deterministic pure logic and transformations.
- Integration: SQL, RLS, RPCs, server actions, authorization, and real
  migration-built database behavior.
- E2E: browser navigation, rendering, accessibility, and critical wiring
  between already-tested layers.

Move coverage downward when the behavior can be proved there. Every E2E test
must name the browser-level behavior that makes E2E necessary. If a test uses
shared mutable data, it must create a unique fixture or restore every mutation
before teardown; seeded rows are read-only unless the test owns them.

For suspected shared-state failures, run the focused test from a clean
database, then the smallest reproducing pair/order. A changed result is
evidence of isolation pollution, not proof that the test is flaky.

## Core Rule

Never read a full long stdout log first. Start with the smallest artifact that
answers: did it pass, which test failed, and what is the first actionable error?

## E2E Reports

`make test-e2e` writes these files:

| File                            | Use                                                          |
| ------------------------------- | ------------------------------------------------------------ |
| `test-reports/e2e-junit.xml`    | Pass/fail, failing test name, error text                     |
| `test-reports/e2e-last-run.log` | Short grep/tail fallback for stack startup or runner output  |
| `test-reports/html/`            | Interactive Playwright report when screenshots/traces matter |
| `test-reports/screenshots/`     | Failure screenshots, traces, and error context               |

First inspect JUnit with targeted search:

```bash
grep -En "<failure|<error|testsuite|testcase|message=" test-reports/e2e-junit.xml
```

If JUnit is not enough, search the last run log rather than opening it:

```bash
grep -En "failed|passed|Error:|Timed out|expect\(|locator|Running|E2E tests complete" test-reports/e2e-last-run.log | tail -120
```

Only then inspect screenshots/traces:

```bash
find test-reports/screenshots -maxdepth 2 -type f | sort
make test-e2e-report
```

## Integration and Unit Reports

Integration tests write `test-reports/integration-junit.xml`.

```bash
grep -En "<failure|<error|testsuite|testcase|message=" test-reports/integration-junit.xml
```

For unit/Vitest output without a JUnit file, use a short filtered command log:

```bash
LOG_FILE=path/to/command.log
grep -En "FAIL|PASS|Error:|AssertionError|expected|received|Test Files|Tests" "$LOG_FILE" | tail -120
```

## Stack Startup Failures

If E2E fails before Playwright runs, inspect Docker status/logs narrowly:

```bash
cd supabase-docker && docker compose -f docker-compose.yml -f docker-compose.e2e.yml ps
cd supabase-docker && docker compose -f docker-compose.yml -f docker-compose.e2e.yml logs --tail=100
```

Do not dump full Docker logs unless a targeted `--tail` does not show the
startup error.

## Reporting Back

Summarize only:

- command run;
- pass/fail count;
- failing test names;
- first actionable error;
- artifact checked;
- next targeted command.

Do not paste full XML, full stdout, full Docker logs, or full screenshots list
unless the user explicitly asks. Report the command, counts, classification,
first actionable error, artifact checked, and next targeted command.
