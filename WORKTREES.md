# Isolated Worktree and Stacked PR Workflow

This is the canonical workflow for human and AI contributors. Read it before
parallel work, branch changes, or stacked pull requests. Provider-specific
agent files point here and must not duplicate these rules.

## One task, one branch, one worktree

Use one worktree for each independent task. Do not switch branches, stash
uncommitted work, or mix unrelated changes in an existing worktree.

Create worktrees under `.worktrees/`, always from a freshly fetched trunk:

    git fetch origin main
    git worktree add .worktrees/<slug> -b <branch-name> origin/main

Use `-b`, never `-B`. If the branch exists, stop and inspect it before
resuming it. Before editing a worktree, verify `pwd`, the current branch,
`git status --short`, recent commits, and any existing PR with `gh pr view`.

Run the task-specific validation and repository lint command before pushing.
If a fix belongs to another task, use that task's worktree.

## Protecting worktrees

Active worktrees do not need to be locked. Git tracks registered worktrees and
normal cleanup must not use force. Lock a paused, long-lived, or otherwise
important worktree when it must not be removed by stale-worktree cleanup:

    git worktree lock --reason "Active PR work" .worktrees/<slug>

Before removing a worktree, verify that its PR is merged, inspect its status,
and check whether it is locked:

    git worktree list --porcelain
    git -C .worktrees/<slug> status --short

If it is locked, stop and review the reason. Unlock it only when removal is
intentional, then remove it without `-f`:

    git worktree unlock .worktrees/<slug>
    git worktree remove .worktrees/<slug>

Use `git worktree prune --dry-run` before pruning stale worktree metadata.

## Stacked pull requests

Use the `gh-stack` extension for stacked pull requests. Install it with
`gh extension install github/gh-stack`.

Before any GitHub operation, verify the intended Muximate profile and account:

    muximate profile
    gh auth status
    gh api user --jq .login

The profile must be the one intended for this repository. Do not diagnose an
account mismatch from a `gh stack` error alone: `gh stack` is public-preview
software, and its GraphQL PR-creation path can fail for an otherwise valid
personal account with an Enterprise Managed User authorization error.

Use `gh stack init`, `add`, `submit`, `view`, `sync`, `rebase`, and `push` for
local stack management. Use `gh stack link` and `gh stack checkout` for PRs
that already exist on GitHub.

Merge from the bottom of the stack upward. Before each merge, verify passing
required checks, zero unresolved review threads, and a valid verified
signature. Do not use an administrator bypass to compensate for a missing
check or unresolved review unless the repository policy explicitly permits it.

Stack metadata is public-preview functionality and can become stale after the
trunk PR merges. Run `gh stack sync`, then `gh stack rebase` and `gh stack push`
before treating a stack as ready.

If `gh stack submit` pushes the branches but fails while creating the remote
PR, keep the local branches and create the PRs with ordinary GitHub CLI
commands. Use the repository pull-request template from
`.github/pull_request_template.md`, preserve the stack order, and set each PR's
base explicitly (the bottom PR targets `main`; each later PR targets the PR
immediately below it). For example:

    git push origin <branch-name>
    gh pr create --base main --head <branch-name> --title "..." --body-file <completed-template>

This fallback is supported for both personal and enterprise accounts. Do not
retry `gh stack submit` repeatedly after a `createPullRequest` authorization
failure; first verify the profile, then use the ordinary PR flow. Optionally
run `gh stack link` after the PRs exist if remote stack metadata is needed.

## Cleanup after merge

After confirming the PR merged on GitHub, remove its worktree and branch with
`git worktree remove .worktrees/<slug>` and `git branch -d <branch-name>`.
Use `-D` only after confirming that no local work remains.
