# Repository Creation Behavior Contract

This document freezes the current repository creation behavior before the larger
workflow refactor. It is the source of truth for Phase 1 normalization work.
Future changes to input behavior should update this contract in the same PR.

## Entry Workflows

The two supported repository creation entrypoints are:

- `.github/workflows/create-repository.yml`
- `.github/workflows/terraform-create-repository.yml`

Both workflows expose the same user-facing inputs for repository metadata,
language/tooling selection, authentication, guardrails, and cleanup behavior.
The direct workflow creates the repository with `gh api`; the Terraform workflow
creates infrastructure with Terraform and then applies template files.

## Authentication And Owner Guardrails

Token resolution uses `.github/actions/resolve-gh-token`.

Auth mode rules:

- GitHub App auth is selected when both `app_id` and `app_private_key` are set.
- App auth requires `app_owner` or the resolved target owner.
- PAT auth is selected from `gh_token` or `secrets.GH_PAT` when App auth is not
  complete.
- Missing credentials fail before repository creation.

Owner guardrail rules:

- `allowed_repo_owners` is optional.
- Empty or whitespace-only `allowed_repo_owners` allows every owner.
- Non-empty allowlists are lowercased and stripped of whitespace.
- The resolved owner is lowercased and must match a comma-delimited allowlist
  entry exactly.
- Allowlist validation runs before token resolution.
- App auth cannot target a personal user account. If the target owner resolves to
  GitHub API type `User` and `auth_mode=app`, the workflow fails and asks the
  caller to use PAT auth or an organization target.

## Input Validation

The current workflows validate these fields before repository creation:

- `env_manager` must be one of `micromamba`, `mise`, or `system`.
- `languages` must match `^[a-zA-Z0-9,_-]+$`.
- `languages` must include at least one valid token.
- `language-agnostic-only` and `agnostic` cannot be combined with other language
  tokens.
- `python_version` must be a dotted numeric version such as `3.13`.
- `node_version` must be a numeric major version such as `24`.
- `go_version` must be a dotted numeric version such as `1.26`.
- `java_version` must be a numeric major version such as `25`.

Supported language tokens in the workflows:

| Input tokens                         | Validation family |
| ------------------------------------ | ----------------- |
| `language-agnostic-only`, `agnostic` | agnostic          |
| `all`                                | all               |
| `go`, `golang`                       | golang            |
| `python`                             | python            |
| `typescript`, `javascript`, `nodejs` | typescript        |
| `node`                               | typescript        |
| `java`, `kotlin`                     | java              |

Unknown tokens fail validation in the workflows.

## Root Language Selection

When multiple language tokens are supplied, the current workflows use the first
comma-separated token to choose the root tooling template. A warning is written
to the step summary.

Root tooling directory mapping:

| First token                           | `LANG_DIR`   |
| ------------------------------------- | ------------ |
| `all`                                 | `agnostic`   |
| `language-agnostic-only`, `agnostic`  | `agnostic`   |
| `python`                              | `python`     |
| `go`, `golang`                        | `golang`     |
| `typescript`, `javascript`, `nodejs`  | `typescript` |
| `node`                                | `typescript` |
| `java`, `kotlin`                      | `java`       |
| any fallback after validation changes | `agnostic`   |

The root tooling files come from
`templates/languages/{LANG_DIR}/providers/{env_manager}`.

## Pre-commit Rendering

The workflows call `go run ./tools/cmd/precommit-renderer`.

Current behavior:

- The root `.pre-commit-config.yaml` uses the selected root `LANG_DIR`.
- Per-language files under `.pre-commit/languages/` use the full `languages`
  input via `--emit-languages`.
- `language-agnostic-only` and empty values render agnostic-only root config and
  emit no per-language files.
- `all` emits all supported language files: `golang`, `python`, `typescript`,
  and `java`.

Known drift to fix in Phase 1:

- `precommit-renderer` currently ignores unknown language tokens and can fall
  back to agnostic behavior.
- The workflows currently reject unknown tokens before calling the renderer.
- Phase 1 must move both behaviors to one shared strict normalizer.

## Release Please Mapping

When `release_tool=release-please`, the workflows set the root
`release-please-config.json` release type from the first language token.

Current mapping:

| First token                | release type       |
| -------------------------- | ------------------ |
| `javascript`, `typescript` | `node`             |
| `python`                   | `python`           |
| `go`                       | `go`               |
| `java`, `kotlin`           | `java`             |
| `rust`                     | `rust`             |
| `ruby`                     | `ruby`             |
| `php`                      | `php`              |
| `terraform`                | `terraform-module` |
| `all`, agnostic, other     | `simple`           |

Some release mapping entries are broader than the currently validated workflow
language tokens. Phase 1 should either preserve that behavior intentionally or
remove unreachable mappings with tests.

## CodeQL Mapping

`.github/scripts/configure-codeql.py` reads `CODEQL_INPUT_LANGUAGES`.

Current mapping:

| Input token                | CodeQL language         |
| -------------------------- | ----------------------- |
| `javascript`, `typescript` | `javascript-typescript` |
| `python`                   | `python`                |
| `java`, `kotlin`           | `java-kotlin`           |
| `go`                       | `go`                    |
| `csharp`                   | `csharp`                |
| `cpp`                      | `cpp`                   |
| `ruby`                     | `ruby`                  |
| `all`                      | all CodeQL languages    |
| agnostic or unsupported    | workflow removed        |

Some CodeQL mapping entries are broader than the currently validated workflow
language tokens. Phase 1 should decide whether those are future-facing support or
stale mappings.

## Test Workflow Contract

`.github/workflows/test-repository-creation.yml` is a manual validation harness.
It dispatches one of the repository creation workflows by `target_workflow` and
`target_ref`, monitors the run, validates the generated repository structure, and
optionally deletes the test repository.

Current accepted `target_workflow` values:

- `create-repository.yml`
- `terraform-create-repository.yml`

Current `target_ref` validation:

- Must not be empty.
- Must match `^[A-Za-z0-9._/-]+$`.
- Must not contain `..`.
- Must not start with `/`.
- Must not end with `/`.

## Phase 1 Requirements

The Phase 1 shared normalizer must preserve or deliberately update the contract
above. At minimum it must test:

- accepted language aliases and canonical families
- rejected unknown language tokens
- `language-agnostic-only` exclusivity
- `all` behavior for root tooling and per-language outputs
- runtime version validation
- root language selection from the first token
- release type mapping
- CodeQL language mapping
