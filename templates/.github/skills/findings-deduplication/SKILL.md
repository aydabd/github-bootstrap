---
name: findings-deduplication
description: Merge duplicate specialist findings, resolve conflicts, and create a short final PR review summary.
license: MIT
---

## Deduplication rules

1. Group by normalized `(file, line-range, category, issue-shape)`.
2. Keep the finding with strongest evidence.
3. Merge recommendations only when they are compatible.
4. Prefer the safest minimal fix when recommendations conflict.
5. Drop low-confidence findings unless multiple agents independently found the same issue.
6. Do not show internal agent names unless useful for audit.

## Final format

```markdown
## Blocking

- `file:line` — Finding. Minimal fix.

## Non-blocking

- `file:line` — Finding. Minimal fix.

## Notes

- Short useful observations only.
```
