# Commit Policy Design

## Goal

Provide a consistent default commit policy for the dogfooding repository,
generated repositories, and monorepos without coupling those repositories at
runtime.

## Source of truth

The canonical policy assets live under `templates/.github/`:

- `templates/.github/workflows/commit-policy.yml` is the thin workflow entrypoint.
- `templates/.github/actions/` contains one composite action per policy responsibility.

The root `.github/` assets are the dogfooding copy of the template assets. The
asset validation script compares shared root and template files and fails when
they drift. Generated repositories receive local copies and therefore do not
depend on this repository at runtime.

## Responsibilities

The workflow separates policy checks into independent jobs and actions:

- Signed-off-by validation checks DCO trailers.
- Conventional-commit validation checks commit messages.
- Pull-request-title validation checks the PR title.

Each action has one responsibility and communicates through explicit inputs.
Sign-off validation does not depend on commitlint, mise, or repository-specific
configuration.

## Default and overrides

When a repository has no commitlint configuration, conventional-commit
validation uses the centralized `@commitlint/config-conventional` default.
Repositories and monorepos can override the config path, command, commit range,
or enabled policy jobs through workflow inputs and local configuration.

The default must be usable by generated repositories independently. Repository-
specific rules remain local overrides and must not modify the canonical shared
action.

## Implementation constraints

- Use `gh api --paginate --slurp` and `jq` for commit retrieval and validation.
- Keep root and template shared assets byte-identical.
- Keep workflow callers thin; policy logic belongs in composite actions.
- Pin third-party actions and tooling versions according to repository policy.
- Verify YAML, parity, formatting, and representative policy behavior in CI.
