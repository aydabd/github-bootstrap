---
name: test-impact-selection
description: Select the minimal useful tests to run based on changed files, impacted components, and repository conventions.
license: MIT
---

## Purpose

Select the minimal useful tests to run based on changed files, impacted components, and repository conventions.

## Review focus

- changed files to test commands
- targeted Gradle/Maven/npm/go/pytest commands
- fast confidence path

## Method

1. Inspect changed files and diff hunks relevant to this skill.
2. Use repository-native tools when available.
3. Prefer exact evidence from changed code.
4. Emit findings using the shared JSONL finding contract.
5. Avoid style-only comments unless they create maintainability or correctness risk.

## Output

```json
{
  "commands": ["<targeted-test-command>"],
  "reason": "One sentence.",
  "fallback_commands": ["<broader-test-command>"]
}
```

## Tooling hints

- Use `grep` or editor search before opening files.
- Use `git`, `grep`, and `gh` CLI. These are universally available and sufficient for all review tasks.
- Do not depend on tools beyond `git`, `grep`, `cat`, `head`, `wc`, and `gh`.
