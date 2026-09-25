# Terraform Module: GitHub Repository Bootstrap

This Terraform module creates the base GitHub repository used by the
[`create-repository.yml`](../.github/workflows/create-repository.yml) GitHub Actions workflow.
The API workflow is the source of truth for bootstrap behavior; both orchestration paths then
use the same shared actions for repository settings, environments, security features, rulesets,
and template files.

## Resources Created

- **`github_repository`** - Base repository matching the API creation request (issues and projects
  enabled, wiki disabled, and an initial commit)
- **`github_repository_environment`** - `dev` and `prod` deployment environments

## Workflow-applied Bootstrap Steps

When run through the Terraform workflow, shared bootstrap actions apply repository settings,
security features, rulesets, and generated repository files. These are wrapper-workflow steps,
not Terraform-managed resources.

## Usage

### Prerequisites

Use the Terraform workflow with a GitHub App. Organization targets use a tenant-installed App and
a short-lived installation token. Personal targets use an App user access token; personal access
tokens are not supported.
Terraform CLI version **1.5 or later** is required (see `versions.tf`).

### Apply via GitHub Actions

1. Fork this repository **or** click **Use this template** inside your organization
2. Configure App mode:
   - use the `production-provisioning` Environment and add `BOOTSTRAP_PRODUCTION_PROVISIONER_APP_PRIVATE_KEY`
     as a protected Actions secret
   - for a personal target, add the App client secret and refresh token as the protected
     `BOOTSTRAP_PRODUCTION_PROVISIONER_APP_CLIENT_SECRET` and
     `BOOTSTRAP_PRODUCTION_PROVISIONER_APP_USER_REFRESH_TOKEN` secrets; set
     `BOOTSTRAP_PRODUCTION_PROVISIONER_APP_CLIENT_ID` as an Environment variable
   - select `production-provisioner` explicitly in the launcher (use `e2e-provisioner` and the
     `e2e` Environment only for disposable E2E runs)
   - pass the target owner as `app_owner` and a comma-separated `allowed_repo_owners` value
     containing the permitted target owners when running the workflow; the selected profile
     supplies the client ID from its Environment variable
   - never pass credentials through workflow inputs
3. Trigger the
   [**Terraform Create Repository**](../.github/workflows/terraform-create-repository.yml) workflow
   from the **Actions** tab. It runs `terraform apply` and then copies the bootstrap template files
   into the new repository.

The target owner must be present in `allowed_repo_owners`; the workflow rejects empty
allowlists and targets outside that explicit list.

## Input Variables

| Variable                    | Required | Default                                    | Description                                                                                                                                      |
| --------------------------- | -------- | ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `github_token`              | **Yes**  | -                                          | GitHub App installation token for organization targets or GitHub App user access token for personal targets, supplied internally by the workflow |
| `repo_name`                 | **Yes**  | -                                          | New repository name                                                                                                                              |
| `repo_owner`                | No       | `""`                                       | Repository owner; may be an organization or the authorized personal account. When empty, the GitHub provider uses the authenticated token owner. |
| `owner_type`                | No       | `"auto"`                                   | Target owner type: `auto`, `user`, or `organization`.                                                                                            |
| `app_installation_identity` | No       | `""`                                       | GitHub App installation owner or identity; empty preserves the workflow's `app_owner` fallback.                                                  |
| `app_permission_profile`    | No       | `"repository-creation"`                    | Explicit App permission profile used for repository creation.                                                                                    |
| `project_owner`             | No       | `""`                                       | Optional GitHub Project owner; must be supplied with `project_number`.                                                                           |
| `project_number`            | No       | `null`                                     | Optional positive GitHub Project number; must be supplied with `project_owner`.                                                                  |
| `token_mode`                | No       | `"auto"`                                   | Token selection mode: `auto`, `installation`, or `user`.                                                                                         |
| `delivery_mode`             | No       | `"embedded"`                               | Workflow delivery mode: `embedded` or `centralized`.                                                                                             |
| `central_repository`        | No       | `""`                                       | Central workflow repository in `OWNER/REPOSITORY` form when centralized delivery is selected.                                                    |
| `central_ref`               | No       | `""`                                       | Immutable centralized workflow ref: `vMAJOR.MINOR.PATCH` or a 40-character commit SHA.                                                           |
| `repo_description`          | No       | `"Repository following SOLID principles…"` | Repository description                                                                                                                           |
| `visibility`                | No       | `"public"`                                 | `public`, `private`, or `internal`                                                                                                               |
| `team_name`                 | No       | `""`                                       | CODEOWNERS owner as a GitHub username or `org/team`; empty uses the workflow app owner (no direct Terraform effect)                              |
| `license_holder`            | No       | `""` (uses `repo_owner`)                   | License copyright holder used only when the wrapper workflow templates the LICENSE file (no direct Terraform effect)                             |
| `languages`                 | No       | `"language-agnostic-only"`                 | Comma-separated languages used by the wrapper workflow for pre-commit rendering and tooling selection (no direct Terraform effect)               |

## Outputs

| Output            | Description                        |
| ----------------- | ---------------------------------- |
| `repository_url`  | HTML URL of the created repository |
| `repository_name` | Name of the created repository     |
| `clone_url_https` | HTTPS clone URL                    |
| `clone_url_ssh`   | SSH clone URL                      |
| `full_name`       | Full `owner/name` repository path  |

## State Management

For team or CI use, store Terraform state remotely. For example, using an S3 backend:

```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "github-bootstrap/terraform.tfstate"
    region = "us-east-1"
  }
}
```

## Differences from the GitHub Actions Workflow

| Feature                 | GitHub Actions Workflow                             | Terraform orchestration path                     |
| ----------------------- | --------------------------------------------------- | ------------------------------------------------ |
| Repository creation     | ✅ GitHub API via `gh` CLI                          | ✅ `github_repository` resource                  |
| Repository settings     | ✅ Shared action via `gh api`                       | ✅ Same shared action                            |
| Vulnerability alerts    | ✅ Shared action via `gh api`                       | ✅ Same shared action                            |
| Dependabot sec. updates | ✅ Shared action via `gh api`                       | ✅ Same shared action                            |
| Environments            | ✅ Shared action via `gh api`                       | ✅ Terraform resources, then shared verification |
| Branch protection       | ✅ Shared ruleset action via `gh api`               | ✅ Same shared ruleset action                    |
| Template files          | ✅ Git clone + copy + push                          | ✅ Handled by the wrapper workflow               |
| Language configuration  | ✅ Renderer-based generation from snippet templates | ✅ Handled by the wrapper workflow               |
| CodeQL workflow         | ✅ Configured by wrapper                            | ✅ Handled by the wrapper workflow               |
| SECURITY.md             | ✅ Copied from template                             | ✅ Handled by the wrapper workflow               |
| CONTRIBUTING.md         | ✅ Copied from template                             | ✅ Handled by the wrapper workflow               |
| Conventional commits    | ✅ commitlint config + linter                       | ✅ Handled by the wrapper workflow               |
| Release Please          | ✅ Workflow + config files                          | ✅ Handled by the wrapper workflow               |
| State tracking          | ❌ Stateless                                        | ✅ Terraform state (drift detection)             |
| Idempotency             | ⚠️ Creates new repo each run                        | ✅ Apply is idempotent with persisted state      |

## Architecture Notes

Repository bootstrap uses shared building blocks across both orchestration paths:

- Actions orchestration: `.github/workflows/create-repository.yml`
- Terraform orchestration: `.github/workflows/terraform-create-repository.yml`
- Shared normalization contract: `tools/pkg/bootstrapinputs` and
  `tools/cmd/bootstrap-inputs`
- Shared composite actions: `render-precommit-configs`,
  `configure-provider-tooling-files`, `configure-release-tool`, `configure-codeql`,
  `apply-repo-settings`, and `apply-repository-ruleset`

For extension work (new language/provider/runtime), use the maintainer guide:

- [`docs/maintainer-guide-adding-support.md`](../docs/maintainer-guide-adding-support.md)

## Troubleshooting

Common failure signatures and quick triage:

| Failure signature                                      | Where it appears                                 | Likely cause                                                    | What to do                                                                                        |
| ------------------------------------------------------ | ------------------------------------------------ | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `Error: creating repository`                           | Terraform apply output                           | App installation lacks required permissions                     | Verify the App installation and the [permission matrix](../docs/github-app-permission-matrix.md). |
| `Error: creating environment`                          | Terraform apply output                           | missing admin rights or existing environment policy constraints | Confirm token has administration rights and inspect existing environment configuration.           |
| Workflow succeeds but expected files are missing       | Post-apply template copy step                    | wrapper workflow failed after Terraform apply                   | Inspect `terraform-create-repository.yml` run logs after the apply step.                          |
| Test harness timeout (`Workflow monitoring timed out`) | `.github/workflows/test-repository-creation.yml` | dispatch/run correlation mismatch                               | Verify monitor filter uses `dispatch_actor` from token identity and matching target ref.          |
