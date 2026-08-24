# Profiled Quality Capabilities and Reusable Delivery Workflows

## Status

Approved scope for issue #78. This design intentionally replaces the
monolithic `lint` contract and does not preserve it as a compatibility alias.

## Goals

- Split quality checks into explicit, independently selectable capabilities.
- Give every capability a stable check contract independent of its tool.
- Package capabilities as real composite actions and reusable workflows.
- Let a new repository choose fully embedded assets or references to a
  user-owned centralized actions/workflows repository.
- Keep generated repositories independent by default.
- Make baseline and optional assets explicit and testable.
- Ensure release-please publishes the change as a breaking major release.

## Non-goals

- Automatically migrating arbitrary existing repositories.
- Overwriting or deleting workflows, actions, tools, or configuration that this
  project cannot prove it owns.
- Retaining the old `lint` workflow or check as a fallback.
- Building a general-purpose migration engine for repositories created by other
  systems.

## Profile model

The canonical profile manifest will classify every generated asset as one of:

- `baseline`: secure foundational assets installed by default;
- `optional:<bundle>`: assets installed only when a named bundle is selected;
- `provider-specific`: assets selected by language or environment provider.

The baseline includes signed-off-by validation, the stable `quality` contract,
language-agnostic foundational/security checks, pinned supply-chain validation,
and worktree/stack delivery assets. The `planning` bundle is disabled by
default and owns issue/project/roadmap templates, skills, agents, and the
Project status workflow.

The manifest will describe each capability's owned files, dependencies,
workflow/check names, permissions, and embedding mode. It is the source of
truth for file selection and ruleset status-check selection.

## Quality capabilities

The monolithic lint workflow is replaced by independently selectable
capabilities:

- `lint-markdown`
- `lint-json`
- `lint-yaml`
- `lint-actions`
- `lint-shell`
- `lint-python`
- `lint-terraform`
- `lint-format`
- `lint-tests`

`lint-actions` runs both `actionlint` and `zizmor --pedantic`. Tool choices
remain implementation details behind the stable capability contract. The
aggregate `quality` workflow invokes the enabled capabilities and exposes the
stable required check used by branch protection.

Every capability has:

1. a composite action for direct local use;
2. a reusable `workflow_call` workflow for repository CI;
3. documented inputs, outputs, permissions, and check naming;
4. SHA-pinned third-party actions and explicit least-privilege permissions;
5. contract tests that verify its generated form and stable check name.

## Embedded and centralized delivery

New repository creation accepts an explicit delivery mode:

- `embedded`: copy the selected composite actions and reusable workflows into
  the generated repository. The result works without any external repository.
- `centralized`: reference a user-owned actions/workflows repository at an
  explicit version or immutable SHA. The generated repository retains its
  profile configuration, provider choices, and ruleset contract locally.

The bootstrap project will provide a creation path for the centralized
repository itself. That repository is owned by the user or organization and
contains the reusable actions, workflows, manifest, examples, release setup,
and consumer documentation. It is not implicitly owned or operated by this
bootstrap project.

Existing repositories are not modified automatically. Documentation and
examples will show how users can manually migrate selected repositories when
they choose. No migration is attempted when files or workflows are ambiguous.

## Profile application

Profile application is shared by new-repository creation and explicit setup
operations. It supports `plan` output and apply behavior for the selected
profile and delivery mode. Applying the same profile repeatedly converges to
the same generated files without duplicates.

In embedded mode, only manifest-owned files are rendered. In centralized mode,
only the generated caller workflows and profile metadata are rendered; the
implementation remains in the configured external repository. User-owned and
unclassified files are preserved.

## Rulesets and check validation

Ruleset status checks are derived from the selected, installed profile. The
application must reject a required check if its manifest entry is absent or
its workflow/job contract is not validated. The old `lint` check is never
added by default and is not retained as a compatibility check.

The baseline ruleset requires the stable signed-off-by and `quality` checks
when those workflows are installed and validated. Optional capabilities may
be required only when explicitly selected. Ruleset updates remain idempotent.

## Existing repository safety

There is no automatic bulk migration. The setup documentation will explain
that users must select and update existing repositories themselves. Any future
manual helper must be opt-in, create reviewable pull requests, and refuse to
touch files not proven to be bootstrap-owned; it is outside this issue's
implementation scope.

## Release and breaking-change policy

The implementation will use conventional commits throughout. The release
boundary will include a commit such as:

    feat!: replace monolithic lint with profiled quality capabilities

with a `BREAKING CHANGE:` footer explaining that generated repositories must
use `quality` and that the old `lint` contract is removed. This allows the
existing release-please configuration to generate a major version release and
include the migration guidance in `CHANGELOG.md`.

## Testing

- Manifest tests cover complete asset classification and profile defaults.
- Workflow contract tests cover every capability's reusable and embedded form.
- Rendering tests cover embedded, centralized, plan, repeat, and disabled
  planning-bundle behavior.
- Shell/API tests verify exact ruleset check selection and idempotent upserts.
- Terraform tests cover creation inputs and delivery-mode propagation.
- Generated workflow validation covers actionlint, zizmor, ShellCheck, YAML,
  and pinned-action checks.
- Release tests verify the breaking conventional-commit metadata and generated
  changelog expectations.
