---
name: pr-context-collection
description: Collect minimal PR context needed by orchestrators and specialists without reading full files or the whole repo.
license: MIT
---

## What to collect

Collect only what reviewers need:

1. `git diff --stat` — size and scope
2. `git diff --name-only` — file list
3. PR title and description (from `gh pr view` or equivalent)
4. For each changed file: `git diff -- <file>` focused hunks only

## Rules

- Do not read full file contents unless a diff hunk is insufficient for a finding.
- Do not scan unchanged files unless a reviewer flags a dependency concern.
- Pass only relevant hunks to each specialist, not the full diff.
- Prefer `gh` CLI for PR metadata when available.

## Output shape

Return a compact summary:

```text
Files changed: N
+lines added / -lines removed
Key changed paths: [list]
PR description: [first 3 lines or title only]
```
