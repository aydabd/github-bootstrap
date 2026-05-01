---
name: test-review
description: Test review for missing coverage, weak assertions, flaky tests, isolation, fixtures, and regression risk.
license: MIT
---

## Purpose

Test review for missing coverage, weak assertions, flaky tests, isolation, fixtures, and regression risk.

## Review focus

- missing unit/integration/e2e tests
- weak assertions
- test pollution
- flaky timing
- missing negative paths
- coverage gaps

## Method

1. Inspect changed files and diff hunks relevant to this skill.
2. Use repository-native tools when available.
3. Prefer exact evidence from changed code.
4. Emit findings using the shared JSONL finding contract.
5. Avoid style-only comments unless they create maintainability or correctness risk.

## Tooling hints

- Use `grep` or editor search before opening files.
- Use `git`, `grep`, and `gh` CLI. These are universally available and sufficient for all review tasks.
- Do not depend on tools beyond `git`, `grep`, `cat`, `head`, `wc`, and `gh`.
