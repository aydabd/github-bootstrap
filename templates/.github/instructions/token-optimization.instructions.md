---
applyTo: "**"
---

# Token Optimization Policy

Use the smallest sufficient context for every agent task.

## Required zero-install path

1. Start with `git status --short` and `git diff --name-only`.
2. Use focused `grep` searches before reading full files.
3. Read only relevant file ranges.
4. Summarize logs and long command output before continuing.
5. Avoid full logs, full diffs, full lockfiles, generated files, or full schemas unless explicitly required.

## Optional accelerators

Use these only when available:

- `scripts/tokf-diff` for semantic diff fallback.
- `scripts/tokf-log` for log filtering.
- `scripts/tokf-json` for JSON filtering.
- `scripts/tokf-pack` only when repository-level context is explicitly needed.
- ToolHive vMCP through the active profile instead of exposing many MCP servers directly.

## Output format

Return only:

- changed files
- key decisions
- commands run
- tests run
- remaining risks
