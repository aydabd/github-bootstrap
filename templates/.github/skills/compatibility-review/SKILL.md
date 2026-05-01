---
name: compatibility-review
description: Compatibility review for backwards/forwards compatibility across APIs, events, database, config, clients, and deployment versions.
license: MIT
---

## Purpose

Compatibility review for backwards/forwards compatibility across APIs, events, database, config, clients, and deployment versions.

## Review focus

- backward incompatibility
- rolling deploy issue
- old client break
- database expand-contract violation
- event versioning gap

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
