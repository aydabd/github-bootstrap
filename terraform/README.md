# Terraform Module: GitHub Repository Bootstrap

This Terraform module creates a fully configured GitHub repository with the same settings as the
[`create-repository.yml`](../.github/workflows/create-repository.yml) GitHub Actions workflow.

## Resources Created

- **`github_repository`** - Repository with squash merge, branch deletion, issues, and projects enabled
- **`github_repository_environment`** - `dev` and `prod` deployment environments
- **`github_repository_ruleset`** - Branch protection for `main` (optional) requiring 1 approving review,
  code-owner review, and the Super-Linter status check

## Usage

### Prerequisites

- Terraform >= 1.5
- GitHub personal access token with `repo` and `admin:org` scopes stored in `TF_VAR_github_token`
  or passed as an input variable

### Apply via CLI

```bash
cd terraform

terraform init

terraform apply \
  -var="github_token=ghp_yourtoken" \
  -var="repo_name=my-new-repo" \
  -var="repo_owner=my-org" \
  -var="visibility=private" \
  -var="team_name=my-team"
```

### Apply via GitHub Actions

Trigger the
[**Terraform Create Repository**](../.github/workflows/terraform-create-repository.yml) workflow
from the **Actions** tab. It runs `terraform apply` and then copies the bootstrap template files
into the new repository.

## Input Variables

| Variable                   | Required | Default                                    | Description                                                                                                          |
| -------------------------- | -------- | ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------- |
| `github_token`             | **Yes**  | -                                          | GitHub PAT with repo + admin:org scopes                                                                              |
| `repo_name`                | **Yes**  | -                                          | New repository name                                                                                                  |
| `repo_owner`               | No       | `""` (uses token owner)                    | Repository owner (user or organization)                                                                              |
| `repo_description`         | No       | `"Repository following SOLID principles…"` | Repository description                                                                                               |
| `visibility`               | No       | `"public"`                                 | `public`, `private`, or `internal`                                                                                   |
| `enable_branch_protection` | No       | `true`                                     | Create branch protection ruleset for `main`                                                                          |
| `team_name`                | No       | `"team-leads"`                             | GitHub team name used by the wrapper workflow when templating CODEOWNERS (no direct Terraform effect)                |
| `license_holder`           | No       | `""` (uses `repo_owner`)                   | License copyright holder used only when the wrapper workflow templates the LICENSE file (no direct Terraform effect) |
| `languages`                | No       | `"language-agnostic-only"`                 | Comma-separated languages used by the wrapper workflow to configure Super-Linter files (no direct Terraform effect)  |

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

| Feature                | GitHub Actions Workflow         | Terraform Module                     |
| ---------------------- | ------------------------------- | ------------------------------------ |
| Repository creation    | ✅ GitHub API via `gh` CLI      | ✅ `github_repository` resource      |
| Repository settings    | ✅ PATCH via `gh api`           | ✅ Inline in `github_repository`     |
| Environments           | ✅ PUT via `gh api`             | ✅ `github_repository_environment`   |
| Branch protection      | ✅ POST rulesets via `gh api`   | ✅ `github_repository_ruleset`       |
| Template files         | ✅ Git clone + copy + push      | ✅ Handled by the wrapper workflow   |
| Language configuration | ✅ `sed` on `.super-linter.env` | ✅ Handled by the wrapper workflow   |
| State tracking         | ❌ Stateless                    | ✅ Terraform state (drift detection) |
| Idempotency            | ⚠️ Creates new repo each run    | ✅ Apply is idempotent               |
