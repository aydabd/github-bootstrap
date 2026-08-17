---
name: git-worktree
description: Use when creating, inspecting, protecting, resuming, or removing isolated Git worktrees.
---

# Git Worktree

Follow `WORKTREES.md`; it is the canonical worktree policy. Use one worktree
and one branch per independent task:

```bash
git fetch origin main
git worktree add .worktrees/<slug> -b <branch> origin/main
git worktree list --porcelain
```

Lock paused or important worktrees with a reason. Before cleanup, confirm the
PR merged, inspect status, and never force-remove a locked worktree:

```bash
git worktree lock --reason "Active PR work" .worktrees/<slug>
git -C .worktrees/<slug> status --short
git worktree unlock .worktrees/<slug>
git worktree remove .worktrees/<slug>
git worktree prune --dry-run
```
