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

Before GitHub operations, verify the active Muximate identity:

```bash
muximate profile
gh auth status
gh api user --jq .login
```

`gh stack` is public-preview software. Its remote GraphQL PR-creation step can
return an Enterprise Managed User authorization error even when the verified
profile is personal and ordinary `gh pr create` works. Treat that as a stack
submission limitation, not proof that Muximate selected the wrong profile.

Use `gh stack init` for a new stack, `gh stack add` to add a dependent branch,
and `gh stack submit` to publish the stack. Use `gh stack view` to inspect the
topology, `gh stack sync` after a lower PR merges, and `gh stack rebase` followed
by `gh stack push` to update descendants. Use `gh stack link` or
`gh stack checkout` when adopting an existing stack.

Merge from the bottom upward only after each PR has passing required checks,
no unresolved review threads, and a verified signed commit.

If `gh stack submit` pushes branches but fails at `createPullRequest`, stop
retrying it. Keep the branches, push them if needed, and create ordinary PRs
with explicit bases and the generated repository's
`.github/pull_request_template.md`:

```bash
git push origin <branch-name>
gh pr create --base main --head <branch-name> --title "..." --body-file <completed-template>
```

Create the bottom PR first (`main`), then each child PR against the branch
immediately below it. Run `gh stack link` afterward only if stack metadata is
required.
