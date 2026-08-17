---
name: github-stack
description: Use when creating, synchronizing, rebasing, submitting, or merging stacked pull requests with gh stack.
---

# GitHub Stack

Use `WORKTREES.md` as the canonical policy for isolation, stack readiness, and
merge order. Install the extension with `gh extension install github/gh-stack`.
Use `gh stack init`, `add`, `submit`, `view`, `sync`, `rebase`, `push`, `link`,
and `checkout` for stack operations. Merge from the bottom upward only after
required checks, review threads, and verified signatures are clean.
