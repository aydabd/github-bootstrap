---
name: performance-review
description: Performance review for expensive loops, N+1 calls, memory pressure, latency, caching, and unnecessary IO.
license: MIT
---

## Purpose

Performance review for expensive loops, N+1 calls, memory pressure, latency, caching, and unnecessary IO.

## Review focus

- N+1 calls
- unbounded loop
- large allocation
- sync blocking
- cache misuse
- repeated serialization

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
