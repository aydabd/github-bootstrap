---
name: frontend-review
description: Frontend review for React/TypeScript patterns, state management, rendering, bundle impact, forms, and UX regressions.
license: MIT
---

## Purpose

Frontend review for React/TypeScript patterns, state management, rendering, bundle impact, forms, and UX regressions.

## Review focus

- unnecessary rerender
- state bug
- type unsafety
- bundle bloat
- form validation gap
- client/server boundary issue

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
