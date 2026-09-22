# Create the GitHub repository
resource "github_repository" "new_repo" {
  name        = var.repo_name
  description = var.repo_description
  visibility  = var.visibility

  has_issues   = true
  has_projects = true
  has_wiki     = false
  auto_init    = true

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
