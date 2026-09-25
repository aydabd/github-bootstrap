variable "github_token" {
  description = "GitHub App installation or user access token supplied by the workflow"
  type        = string
  sensitive   = true
}

variable "repo_name" {
  description = "New repository name"
  type        = string
}

variable "repo_owner" {
  description = "Repository owner (organization or authorized personal account); empty uses the authenticated token owner"
  type        = string
  default     = ""
}

variable "owner_type" {
  description = "Target owner type: auto, user, or organization"
  type        = string
  default     = "auto"

  validation {
    condition     = contains(["auto", "user", "organization"], var.owner_type)
    error_message = "owner_type must be one of: auto, user, organization."
  }
}

variable "app_installation_identity" {
  description = "GitHub App installation owner or identity; empty preserves app_owner compatibility"
  type        = string
  default     = ""
}

variable "app_permission_profile" {
  description = "Permission profile for the repository-creation App token"
  type        = string
  default     = "repository-creation"

  validation {
    condition = contains([
      "repository-creation", "repository-setup", "repository-cleanup", "e2e-dispatch",
      "e2e-fixture", "weekly-tooling", "maintenance-labeling", "workflow-approval",
      "maintenance-review", "maintenance-merge", "release-please", "e2e-lifecycle"
    ], var.app_permission_profile)
    error_message = "app_permission_profile is not a supported GitHub App permission profile."
  }
}

variable "project_owner" {
  description = "Optional GitHub Project owner; must be paired with project_number"
  type        = string
  default     = ""
}

variable "project_number" {
  description = "Optional GitHub Project number; must be paired with project_owner"
  type        = number
  default     = null

  validation {
    condition     = var.project_number == null || var.project_number > 0
    error_message = "project_number must be a positive integer when supplied."
  }
}

variable "token_mode" {
  description = "Token mode: auto, installation, or user"
  type        = string
  default     = "auto"

  validation {
    condition     = contains(["auto", "installation", "user"], var.token_mode)
    error_message = "token_mode must be one of: auto, installation, user."
  }
}

variable "delivery_mode" {
  description = "Workflow delivery mode: embedded or centralized"
  type        = string
  default     = "embedded"

  validation {
    condition     = contains(["embedded", "centralized"], var.delivery_mode)
    error_message = "delivery_mode must be one of: embedded, centralized."
  }
}

variable "central_repository" {
  description = "Optional central workflow repository in OWNER/REPOSITORY form"
  type        = string
  default     = ""
}

variable "central_ref" {
  description = "Optional immutable central workflow ref: vMAJOR.MINOR.PATCH or 40-character SHA"
  type        = string
  default     = ""

  validation {
    condition     = var.central_ref == "" || can(regex("^(v[0-9]+\\.[0-9]+\\.[0-9]+|[0-9a-fA-F]{40})$", var.central_ref))
    error_message = "central_ref must be an immutable semver tag or 40-character commit SHA."
  }
}

variable "repo_description" {
  description = "Repository description"
  type        = string
  default     = "Repository following SOLID principles and best practices"
}

variable "visibility" {
  description = "Repository visibility (public, private, or internal)"
  type        = string
  default     = "public"

  validation {
    condition     = contains(["public", "private", "internal"], var.visibility)
    error_message = "Visibility must be one of: public, private, internal."
  }
}

variable "team_name" {
  description = "CODEOWNERS owner (GitHub username or org/team); empty uses the workflow app owner"
  type        = string
  default     = ""
}

variable "license_holder" {
  description = "License copyright holder name. Defaults to repo_owner."
  type        = string
  default     = ""
}

variable "languages" {
  description = "Programming languages (comma-separated: javascript,typescript,python or 'all' for monorepo)"
  type        = string
  default     = "language-agnostic-only"
}

variable "enable_repo_settings" {
  description = "Create dev/prod GitHub repository environments. When false, the dev and prod environment resources are skipped."
  type        = bool
  default     = true
}

variable "github_host" {
  description = "GitHub hostname. Use 'github.com' for GitHub.com or your GHES hostname (e.g. 'ghes.example.com')."
  type        = string
  default     = "github.com"
}
