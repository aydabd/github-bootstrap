variable "github_token" {
  description = "GitHub personal access token with repository permissions"
  type        = string
  sensitive   = true
}

variable "repo_name" {
  description = "New repository name"
  type        = string
}

variable "repo_owner" {
  description = "Repository owner (user or organization). Defaults to the token owner."
  type        = string
  default     = ""
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

variable "enable_branch_protection" {
  description = "Enable branch protection rules for the main branch"
  type        = bool
  default     = true
}

variable "team_name" {
  description = "GitHub team for code owners (e.g., team-leads)"
  type        = string
  default     = "team-leads"
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
