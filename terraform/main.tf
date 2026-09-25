# Create the GitHub repository
resource "github_repository" "new_repo" {
  name        = var.repo_name
  description = var.repo_description
  visibility  = var.visibility

  has_issues   = true
  has_projects = true
  has_wiki     = false
  auto_init    = true

  lifecycle {
    precondition {
      condition     = (var.project_owner == "") == (var.project_number == null)
      error_message = "project_owner and project_number must be supplied together."
    }
    precondition {
      condition     = var.delivery_mode != "centralized" || (var.central_repository != "" && var.central_ref != "")
      error_message = "central_repository and central_ref are required for centralized delivery."
    }
    precondition {
      condition     = var.delivery_mode != "centralized" || can(regex("^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?/[A-Za-z0-9._-]{1,100}$", var.central_repository))
      error_message = "central_repository must match OWNER/REPOSITORY."
    }
  }

}

# Create development environment (no wait, no reviewers required)
resource "github_repository_environment" "dev" {
  count       = var.enable_repo_settings ? 1 : 0
  environment = "dev"
  repository  = github_repository.new_repo.name

  depends_on = [github_repository.new_repo]
}

# Create production environment
resource "github_repository_environment" "prod" {
  count       = var.enable_repo_settings ? 1 : 0
  environment = "prod"
  repository  = github_repository.new_repo.name

  depends_on = [github_repository.new_repo]
}
