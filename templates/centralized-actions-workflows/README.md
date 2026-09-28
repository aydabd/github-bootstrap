# Centralized Actions and Workflows

This directory is a seed for a repository owned by the user or organization
that wants to share quality automation across multiple repositories. It is
independent of `github-bootstrap` after creation.

This seeded repository contains the reusable workflows at
`.github/workflows/pull-request.yml`, `.github/workflows/quality.yml`, and
`.github/workflows/pr-policy.yml`, their
composite quality and PR-policy actions, setup actions, lint scripts, and lint
configuration. The workflows intentionally declare only `workflow_call`; the
consumer repository should define thin workflows with its own `push` or
`pull_request` triggers. The consumer retains its own Makefile, provider
files, repository source/configuration, Project identity, secrets, and final
ruleset enforcement, but does not copy central quality or PR-policy
implementation. Publish immutable release tags or use commit SHAs, then
configure consumer repositories with:

Repository settings and rulesets are not redefined in this package. Central
repository provisioning uses the bootstrap repository's canonical
`.github/config/repo-settings.json` and `ruleset-default.json` through the
shared setup scripts. Only the centralized aggregate check name is supplied as
an explicit binding for the central package.

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

The pull-request caller uses the same central repository and ref. It is the
only required consumer workflow for the centralized baseline and fans out to
the central PR-policy and quality workflows:

```yaml
name: Pull Request

on:
  pull_request:
    branches: [main]

jobs:
  pull-request:
    uses: "OWNER/REPOSITORY/.github/workflows/pull-request.yml@IMMUTABLE_REF"
    with:
      capabilities: "lint-markdown,lint-json,lint-yaml,lint-actions,lint-shell,lint-python,lint-terraform,lint-format,lint-tests"
      environment-manager: system
      central-repository: "OWNER/REPOSITORY"
      central-ref: "IMMUTABLE_REF"
    permissions:
      contents: read
      pull-requests: read
```

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
