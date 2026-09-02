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

All language/runtime normalization logic must live in `bootstrapinputs`. Do not reimplement parsing in workflow shell.

### Template composition

- `templates/languages/<language>/pre-commit-snippets/`
- `templates/languages/<language>/providers/<provider>/`
- `templates/languages/<language>/pyproject.toml` + `uv.lock`

Provider files are selected by `configure-provider-tooling-files` and rendered by workflow orchestration.

### Python tooling (uv)

`uv` is the single source of truth for every Python package used for linting
(`pre-commit`, `yamllint`, `editorconfig-checker`, `zizmor`, and — for the
Python language — `ruff`, `mypy`, `pytest*`). Micromamba and mise manage only
runtimes and non-Python binaries.

- The tool set is declared in `pyproject.toml` (`[dependency-groups] dev`) and
  pinned in the committed `uv.lock`, at the repo root and in each
  `templates/languages/<language>/`.
- Every provider's `setup-env` runs `uv sync --locked` to build an isolated
  `.venv`; `make`/CI invoke pre-commit as `uv run pre-commit …`.
- To bump a Python tool: edit `pyproject.toml` (or run
  `uv lock --upgrade-package <name>`), run `uv lock`, and commit the updated
  `uv.lock`. The weekly tooling updater refreshes it under the cooldown.
- `scripts/test-uv-python-tooling-contract.sh` fails the build if any
  `environment.yml` / `mise.toml` / setup-lint action reintroduces pip, or if a
  `pyproject.toml` lacks a sibling `uv.lock`.

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
   - create `templates/languages/<language>/pyproject.toml`, then run `uv lock`
     in that directory to commit the matching `uv.lock`
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
5. Validate local quality flow with `make quality` for the provider mode.

## Add/Change Runtime Versions

1. Update choice inputs in both create workflows and the test workflow.
2. Update validation and normalization constraints in `tools/pkg/bootstrapinputs`.
3. Update any provider templates that pin runtime versions.
4. Add or update tests for accepted and rejected versions.

## Required Validation

Run all required checks before opening a PR:

```bash
LINT_MODE=check make quality
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
