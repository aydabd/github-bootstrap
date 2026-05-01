---
name: breaking-change-review
description: Breaking-change review for public APIs, events, configs, feature flags, CLI behavior, and migration compatibility.
license: MIT
---

## Purpose

Breaking-change review for public APIs, events, configs, feature flags, CLI behavior, and migration compatibility.

## Review focus

- removed field
- changed default
- config rename
- event shape break
- API incompatibility
- client migration missing

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
