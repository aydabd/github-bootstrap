# Centralized Actions and Workflows

This directory is a seed for a repository owned by the user or organization
that wants to share quality automation across multiple repositories. It is
independent of `github-bootstrap` after creation.

This seeded repository contains the reusable workflow at
`.github/workflows/quality.yml`, its composite quality actions, setup actions,
lint scripts, and lint configuration. The workflow intentionally declares
only `workflow_call`; the consumer repository should define its own workflow
with `push` and `pull_request` triggers. The consumer retains its own
Makefile, provider files, and repository source/configuration, but does not
copy the central quality actions or lint scripts. Publish immutable release
tags or use commit SHAs, then configure consumer repositories with:

```yaml
delivery_mode: centralized
central_repository: my-org/shared-actions-workflows
central_ref: v1.0.0
```

Consumers reference the central workflow at a pinned ref. The called workflow
checks out and validates the consumer repository. Local repository
configuration, provider selection, and branch rules remain local. The central
repository itself does not run consumer quality checks on pushes or pull
requests. This project does not automatically migrate existing repositories;
use the example in `examples/consumer-quality.yml` when manually updating
selected repositories.

Consumers can remain on different immutable package versions while they are
upgraded independently. See `examples/consumer-quality-versions.yml` for a
release-tag-pinned consumer and a commit-SHA-pinned consumer using the same
workflow interface.

The machine-readable package identity and release policy are recorded in
`.github/centralized-workflows.json`. The seed process materializes its
`source_repository` from the target owner and repository, so forks and other
organizations retain their own identity. Its version identifies the seed
package; the release tag or commit SHA selected by each consumer identifies
the exact workflow implementation it runs. Inspect this manifest when
preparing a consumer upgrade, then update that consumer's pinned `central_ref`
in a reviewed pull request.

## Ownership and releases

The central repository should use its own owners, CODEOWNERS, permissions,
release process, and security policy. Update consumers through deliberate
pull requests after publishing a new version. Do not use a floating branch as
the production ref. The bootstrap validator accepts only a complete
`OWNER/REPOSITORY` and an immutable `vMAJOR.MINOR.PATCH` release tag or
40-character commit SHA. Each consumer may pin a different release or SHA;
upgrading changes only its `central_ref` after the central repository has
published and validated the new version.
