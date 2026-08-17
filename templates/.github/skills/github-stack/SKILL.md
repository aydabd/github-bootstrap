---
name: github-stack
description: Use when creating, synchronizing, rebasing, submitting, or merging stacked pull requests with gh stack.
---

# GitHub Stack

Read the repository's `WORKTREES.md` before changing stack topology. It is the
canonical policy for branch isolation, readiness checks, and merge order.

Install the extension when it is not available:

```bash
gh extension install github/gh-stack
```

Use `gh stack init` for a new stack, `gh stack add` to add a dependent branch,
and `gh stack submit` to publish the stack. Use `gh stack view` to inspect the
topology, `gh stack sync` after a lower PR merges, and `gh stack rebase` followed
by `gh stack push` to update descendants. Use `gh stack link` or
`gh stack checkout` when adopting an existing stack.

Merge from the bottom upward only after each PR has passing required checks,
no unresolved review threads, and a verified signed commit.
