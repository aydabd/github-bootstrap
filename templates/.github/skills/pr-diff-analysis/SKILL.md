---
name: pr-diff-analysis
description: Analyze pull request diffs efficiently and route files to the right review specialists without loading the whole repository.
license: MIT
---

## Diff strategy

1. Read the file list first.
2. Group files by domain: backend, frontend, infra, database, ci-cd, docs, tests, contracts, dependencies.
3. Read only focused hunks for each specialist.
4. For large diffs, summarize per file before specialist review.
5. Avoid reading generated files unless the change is explicitly about generated output.

## Commands

```bash
git diff --name-status "$BASE"...HEAD
git diff --stat "$BASE"...HEAD
git diff --unified=80 "$BASE"...HEAD -- path/to/file
```

## Ignore by default

- lockfiles unless dependency review is active
- generated snapshots unless test review is active
- minified assets
- vendored code
