---
name: architecture-review
description: Architecture review for SOLID, layering, boundaries, coupling, cohesion, extensibility, and maintainability.
license: MIT
---

## Purpose

Architecture review for SOLID, layering, boundaries, coupling, cohesion, extensibility, and maintainability.

## Review focus

- layer violation
- tight coupling
- mixed responsibilities
- leaky abstraction
- hard-coded policy
- poor extension seam

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
