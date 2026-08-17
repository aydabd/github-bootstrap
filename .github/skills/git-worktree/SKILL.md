---
name: git-worktree
description: Use when creating, inspecting, protecting, resuming, or removing isolated Git worktrees.
---

# Git Worktree

Follow `WORKTREES.md` as the canonical policy. Use one worktree and branch per
task. Lock paused or important worktrees with a reason, inspect before cleanup,
and never force-remove a locked worktree.

```bash
git fetch origin main
git worktree add .worktrees/<slug> -b <branch> origin/main
git worktree list --porcelain
git worktree lock --reason "Active PR work" .worktrees/<slug>
git -C .worktrees/<slug> status --short
git worktree unlock .worktrees/<slug>
git worktree remove .worktrees/<slug>
git worktree prune --dry-run
```
