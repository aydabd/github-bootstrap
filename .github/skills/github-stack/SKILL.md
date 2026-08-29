---
name: github-stack
description: Use when creating, synchronizing, rebasing, submitting, or merging stacked pull requests with gh stack.
---

# GitHub Stack

Use `WORKTREES.md` as the canonical policy for isolation, stack readiness, and
merge order. Install the extension with `gh extension install github/gh-stack`.

Before GitHub operations, verify the active Muximate identity:

    muximate profile
    gh auth status
    gh api user --jq .login

`gh stack` is public-preview software. Its remote GraphQL PR-creation step can
return an Enterprise Managed User authorization error even when the verified
profile is personal and ordinary `gh pr create` works. Treat that as a stack
submission limitation, not proof that Muximate selected the wrong profile.

Use `gh stack init`, `add`, `submit`, `view`, `sync`, `rebase`, `push`, `link`,
and `checkout` for stack operations. Merge from the bottom upward only after
required checks, review threads, and verified signatures are clean.

If `gh stack submit` pushes branches but fails at `createPullRequest`, stop
retrying it. Keep the branches, push them if needed, and create ordinary PRs
with explicit bases and the repository's `.github/pull_request_template.md`:

    git push origin <branch-name>
    gh pr create --base main --head <branch-name> --title "..." --body-file <completed-template>

Create the bottom PR first (`main`), then each child PR against the branch
immediately below it. Run `gh stack link` afterward only if stack metadata is
required.
