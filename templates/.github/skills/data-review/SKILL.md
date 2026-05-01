---
name: data-review
description: Data review for migrations, data compatibility, transactions, indexing, retention, and data-loss risk.
license: MIT
---

## Purpose

Data review for migrations, data compatibility, transactions, indexing, retention, and data-loss risk.

## Review focus

- destructive migration
- missing rollback
- bad transaction boundary
- index missing
- retention issue
- data corruption risk

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
