# Terraform Module: GitHub Repository Bootstrap

This Terraform module creates a fully configured GitHub repository with the same settings as the
[`create-repository.yml`](../.github/workflows/create-repository.yml) GitHub Actions workflow.

## Resources Created

- **`github_repository`** - Repository with squash merge, branch deletion, issues, projects enabled,
  and vulnerability alerts enabled
- **`github_repository_environment`** - `dev` and `prod` deployment environments
- **`github_repository_ruleset`** - Branch protection for `main` (optional) requiring one approving review,
  latest-push approval, resolved review threads, `quality` and `CodeRabbit` status checks,
  and linear history (no merge commits)

  CodeRabbit must be installed and have review quota available when this ruleset is enabled;
  otherwise automation PRs can remain blocked waiting for the required `CodeRabbit` status.

## Usage

### Prerequisites

Use the Terraform workflow with a GitHub App. Organization targets use a tenant-installed App and
a short-lived installation token. Personal targets use an App user access token; personal access
tokens are not supported.
Terraform CLI version **1.5 or later** is required (see `versions.tf`).

### Apply via GitHub Actions

1. Fork this repository **or** click **Use this template** inside your organization
2. Configure App mode:
   - for an organization target, add `BOOTSTRAP_APP_PRIVATE_KEY` as a protected Actions secret
   - for a personal target, add the authorized App user access token as the protected
     `BOOTSTRAP_APP_USER_TOKEN` reusable-workflow secret
   - pass `client_id`, the target owner as `app_owner`, and a comma-separated
     `allowed_repo_owners` value containing the permitted target owners when running the workflow
   - never pass credentials through workflow inputs
3. Trigger the
   [**Terraform Create Repository**](../.github/workflows/terraform-create-repository.yml) workflow
   from the **Actions** tab. It runs `terraform apply` and then copies the bootstrap template files
   into the new repository.

The target owner must be present in `allowed_repo_owners`; the workflow rejects empty
allowlists and targets outside that explicit list.

## Input Variables

| Variable                   | Required | Default                                    | Description                                                                                                                                                                                                                                |
| -------------------------- | -------- | ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `github_token`             | **Yes**  | -                                          | GitHub App installation token for organization targets or GitHub App user access token for personal targets, supplied internally by the workflow                                                                                           |
| `repo_name`                | **Yes**  | -                                          | New repository name                                                                                                                                                                                                                        |
| `repo_owner`               | No       | `""`                                       | Repository owner; may be an organization or the authorized personal account. When empty, the GitHub provider uses the authenticated token owner.                                                                                           |
| `repo_description`         | No       | `"Repository following SOLID principles…"` | Repository description                                                                                                                                                                                                                     |
| `visibility`               | No       | `"public"`                                 | `public`, `private`, or `internal`                                                                                                                                                                                                         |
| `enable_branch_protection` | No       | `false`                                    | Opt-in: create a Terraform-managed branch protection ruleset for `main`. Disabled by default; bootstrap workflows apply the default ruleset via `apply-repository-ruleset`. Enable only when managing rulesets through Terraform directly. |
| `team_name`                | No       | `"team-leads"`                             | GitHub team name used by the wrapper workflow when templating CODEOWNERS (no direct Terraform effect)                                                                                                                                      |
| `license_holder`           | No       | `""` (uses `repo_owner`)                   | License copyright holder used only when the wrapper workflow templates the LICENSE file (no direct Terraform effect)                                                                                                                       |
| `languages`                | No       | `"language-agnostic-only"`                 | Comma-separated languages used by the wrapper workflow for pre-commit rendering and tooling selection (no direct Terraform effect)                                                                                                         |

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

| Feature                 | GitHub Actions Workflow                             | Terraform Module                     |
| ----------------------- | --------------------------------------------------- | ------------------------------------ |
| Repository creation     | ✅ GitHub API via `gh` CLI                          | ✅ `github_repository` resource      |
| Repository settings     | ✅ PATCH via `gh api`                               | ✅ Inline in `github_repository`     |
| Vulnerability alerts    | ✅ PUT via `gh api`                                 | ✅ `vulnerability_alerts = true`     |
| Dependabot sec. updates | ✅ PUT via `gh api`                                 | ⚠️ Not directly in the provider      |
| Environments            | ✅ PUT via `gh api`                                 | ✅ `github_repository_environment`   |
| Branch protection       | ✅ POST rulesets via `gh api`                       | ✅ `github_repository_ruleset`       |
| Template files          | ✅ Git clone + copy + push                          | ✅ Handled by the wrapper workflow   |
| Language configuration  | ✅ Renderer-based generation from snippet templates | ✅ Handled by the wrapper workflow   |
| CodeQL workflow         | ✅ Configured by wrapper                            | ✅ Handled by the wrapper workflow   |
| SECURITY.md             | ✅ Copied from template                             | ✅ Handled by the wrapper workflow   |
| CONTRIBUTING.md         | ✅ Copied from template                             | ✅ Handled by the wrapper workflow   |
| Conventional commits    | ✅ commitlint config + linter                       | ✅ Handled by the wrapper workflow   |
| Release Please          | ✅ Workflow + config files                          | ✅ Handled by the wrapper workflow   |
| State tracking          | ❌ Stateless                                        | ✅ Terraform state (drift detection) |
| Idempotency             | ⚠️ Creates new repo each run                        | ✅ Apply is idempotent               |

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

| Failure signature                                      | Where it appears                                 | Likely cause                                                    | What to do                                                                                                                              |
| ------------------------------------------------------ | ------------------------------------------------ | --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `Error: creating repository`                           | Terraform apply output                           | App installation lacks required permissions                     | Verify the App installation and the [permission matrix](../docs/github-app-permission-matrix.md).                                       |
| `Error: creating repository ruleset`                   | Terraform apply output                           | plan/features do not support rulesets or settings conflict      | Keep `enable_branch_protection=false` unless Terraform should own rulesets, and avoid dual ownership with workflow ruleset application. |
| `Error: creating environment`                          | Terraform apply output                           | missing admin rights or existing environment policy constraints | Confirm token has administration rights and inspect existing environment configuration.                                                 |
| Workflow succeeds but expected files are missing       | Post-apply template copy step                    | wrapper workflow failed after Terraform apply                   | Inspect `terraform-create-repository.yml` run logs after the apply step.                                                                |
| Test harness timeout (`Workflow monitoring timed out`) | `.github/workflows/test-repository-creation.yml` | dispatch/run correlation mismatch                               | Verify monitor filter uses `dispatch_actor` from token identity and matching target ref.                                                |
