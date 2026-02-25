locals {
  # Use provided repo_owner or fall back to the token owner (empty string delegates to provider)
  effective_owner  = var.repo_owner
  effective_holder = var.license_holder != "" ? var.license_holder : var.repo_owner
}

# Create the GitHub repository
resource "github_repository" "new_repo" {
  name        = var.repo_name
  description = var.repo_description
  visibility  = var.visibility

  has_issues   = true
  has_projects = true
  has_wiki     = false
  auto_init    = true

  # Merge strategy: squash merge preferred, rebase allowed, merge commits disabled
  allow_squash_merge        = true
  allow_merge_commit        = false
  allow_rebase_merge        = true
  squash_merge_commit_title = "PR_TITLE"
  delete_branch_on_merge    = true
}

# Create development environment (no wait, no reviewers required)
resource "github_repository_environment" "dev" {
  environment = "dev"
  repository  = github_repository.new_repo.name

  depends_on = [github_repository.new_repo]
}

# Create production environment
resource "github_repository_environment" "prod" {
  environment = "prod"
  repository  = github_repository.new_repo.name

  deployment_branch_policy {
    protected_branches     = true
    custom_branch_policies = false
  }

  depends_on = [github_repository.new_repo]
}

# Apply branch protection ruleset for the main branch
resource "github_repository_ruleset" "main_protection" {
  count = var.enable_branch_protection ? 1 : 0

  name        = "main-protection"
  repository  = github_repository.new_repo.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/heads/main"]
      exclude = []
    }
  }

  rules {
    deletion         = true
    non_fast_forward = true

    pull_request {
      required_approving_review_count   = 1
      dismiss_stale_reviews_on_push     = true
      require_code_owner_review         = true
      require_last_push_approval        = true
      required_review_thread_resolution = true
    }

    required_status_checks {
      strict_required_status_checks_policy = true

      required_check {
        context = "Super-Linter / Lint and Auto-format Code"
      }
    }
  }

  bypass_actors {
    actor_id    = 5
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }

  depends_on = [github_repository.new_repo]
}
