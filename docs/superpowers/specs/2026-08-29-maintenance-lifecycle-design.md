# Maintenance Automation Lifecycle Design

## Goal

Route weekly tooling, Dependabot, and release-please pull requests through the
same verified maintenance lifecycle without weakening repository rulesets.

## Design

The existing Writer App remains responsible for maintenance labels and the
existing Reviewer App remains responsible for workflow approval, review, and
auto-merge. A small pull-request-target workflow will classify only trusted
automation authors: `dependabot[bot]`, or release-please PRs identified by the
`autorelease: pending` label and an allowed release automation author. It will
add the common `automation: maintenance` and `automation: validating` labels,
while preserving `autorelease: pending` and existing dependency labels.

The safety and merge validators will accept the two additional lifecycle
inputs without accepting arbitrary actors, forks, stale heads, blocked labels,
failed checks, unresolved Copilot review, or workflow changes. All mutation
continues through scoped GitHub App tokens and normal ruleset enforcement.

## Verification

Shell contract fixtures will cover successful Dependabot and release-please
classification plus rejected authors, missing release labels, forks, stale
heads, blocked labels, failed checks, and missing review approval. Generated
workflow and manifest contracts will verify least-privilege permissions and
that release labels are preserved. The complete repository quality gate remains
required.
