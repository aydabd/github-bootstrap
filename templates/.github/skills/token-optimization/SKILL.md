---
name: token-optimization
description: Use zero-install context minimization first, with optional local optimization tooling when available.
license: MIT
---

# Token Optimization Skill

Use this before large context operations.

## Required zero-install path

1. Start with changed files: `git status --short` and `git diff --name-only`.
2. Use focused `grep` searches before reading full files.
3. Read only relevant file ranges.
4. Summarize logs and long command output before continuing.
5. Keep final output to changed files, commands run, tests run, and risks.

## Optional accelerators

Use these only when available:

- `scripts/tokf-diff`
- `scripts/tokf-log`
- `scripts/tokf-json`
- `scripts/tokf-pack`
- ToolHive vMCP active profile
