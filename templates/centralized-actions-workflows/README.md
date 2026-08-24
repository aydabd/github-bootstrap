# Centralized Actions and Workflows

This directory is a seed for a repository owned by the user or organization
that wants to share quality automation across multiple repositories. It is
independent of `github-bootstrap` after creation.

This seeded repository contains the reusable workflow at
`.github/workflows/quality.yml` and its setup actions under
`.github/actions/setup-lint-*`. Copy the referenced setup actions into every
consumer repository as well: the workflow checks out and operates on the
calling consumer repository, and its relative
`./.github/actions/setup-lint-*` references resolve there. Each consumer must
therefore retain its own Makefile, provider files, scripts, setup actions, and
lint configuration. The reusable workflow intentionally declares only
`workflow_call`; the consumer repository should define its own workflow with
`push` and `pull_request` triggers. Publish immutable release tags or use
commit SHAs, then configure consumer repositories with:

```yaml
delivery_mode: centralized
central_repository: my-org/shared-actions-workflows
central_ref: v1.0.0
```

Consumers reference the central workflow at a pinned ref. The called workflow
checks out and validates the consumer repository, so the consumer must retain
its own Makefile, provider files, setup actions, and lint configuration. Local
repository configuration, provider selection, and branch rules remain local.
The central repository itself does not run consumer quality checks on pushes or
pull requests. This project does not automatically migrate existing
repositories; use the example in `examples/consumer-quality.yml` when manually
updating selected repositories.

## Ownership and releases

The central repository should use its own owners, CODEOWNERS, permissions,
release process, and security policy. Update consumers through deliberate
pull requests after publishing a new version. Do not use a floating branch as
the production ref.
