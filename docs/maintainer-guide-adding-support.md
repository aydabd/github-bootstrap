# Maintainer Guide: Add Language, Provider, or Runtime Support

This guide is the single place to update when extending bootstrap support.

## Scope

Use this checklist when adding any of the following:

- new language template
- new provider variant (`micromamba`, `mise`, `system`, or future provider)
- new runtime version options (Python, Node.js, Go, Java)

## Source-of-Truth Files

### Workflow-level input schema

- `.github/workflows/create-repository.yml`
- `.github/workflows/terraform-create-repository.yml`
- `.github/workflows/test-repository-creation.yml`

When you add a workflow input or option in one create workflow, mirror it in the other create workflow and the test harness.

### Normalization and validation contract

- `tools/pkg/bootstrapinputs`
- `tools/cmd/bootstrap-inputs`
- `docs/repository-creation-behavior-contract.md`

All language/runtime normalization logic must live in `bootstrapinputs`. Do not reimplement parsing in workflow shell.

### Template composition

- `templates/languages/<language>/pre-commit-snippets/`
- `templates/languages/<language>/providers/<provider>/`

Provider files are selected by `configure-provider-tooling-files` and rendered by workflow orchestration.

### Composite actions

- `.github/actions/render-precommit-configs`
- `.github/actions/configure-provider-tooling-files`
- `.github/actions/configure-release-tool`
- `.github/actions/configure-codeql`
- `.github/actions/apply-repo-settings`
- `.github/actions/apply-repository-ruleset`

Keep each action single-purpose and declarative.

## Add a New Language

1. Add language assets:
   - create `templates/languages/<language>/pre-commit-snippets/`
   - create `templates/languages/<language>/providers/{micromamba,mise,system}/`
2. Update normalization allow-list and alias mapping in `tools/pkg/bootstrapinputs`.
3. Update release-type mapping in `tools/pkg/bootstrapinputs` if needed.
4. Update CodeQL language mapping if applicable.
5. Ensure `tools/cmd/precommit-renderer` output includes the new language snippets.
6. Update behavior contract documentation.

## Add a New Provider

1. Add provider directories for each supported language:
   - `templates/languages/<language>/providers/<provider>/`
2. Add required provider files (for example provider-specific bootstrap config).
3. Update workflow input allow-lists in:
   - `create-repository.yml`
   - `terraform-create-repository.yml`
   - `test-repository-creation.yml`
4. Update provider selection logic in `configure-provider-tooling-files` if needed.
5. Validate local lint flow with `make lint` for the provider mode.

## Add/Change Runtime Versions

1. Update choice inputs in both create workflows and the test workflow.
2. Update validation and normalization constraints in `tools/pkg/bootstrapinputs`.
3. Update any provider templates that pin runtime versions.
4. Add or update tests for accepted and rejected versions.

## Required Validation

Run all required checks before opening a PR:

```bash
LINT_MODE=check make lint
```

When changing language/provider behavior, also run the manual test harness:

1. Trigger `.github/workflows/test-repository-creation.yml`
2. Run both API and Terraform presets for your change surface
3. Verify summary includes API parity checks and lint dispatch success

## Common Pitfalls

- Updating only one create workflow and forgetting the other
- Adding workflow input choices without matching `bootstrapinputs` validation
- Editing template snippets without regenerating/validating rendered pre-commit outputs
- Introducing branch-protection/ruleset behavior drift between Actions and Terraform paths

## Definition of Done

A support-extension PR is done when:

- create workflows and test workflow remain schema-aligned
- normalization behavior is implemented only in `bootstrapinputs`
- templates and actions remain single-responsibility
- lint/test harness checks pass
- docs are updated (README and behavior contract where relevant)
