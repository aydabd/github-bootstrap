output "repository_url" {
  description = "The URL of the created GitHub repository"
  value       = github_repository.new_repo.html_url
}

output "repository_name" {
  description = "The name of the created GitHub repository"
  value       = github_repository.new_repo.name
}

output "clone_url_https" {
  description = "The HTTPS clone URL of the created repository"
  value       = github_repository.new_repo.http_clone_url
}

output "clone_url_ssh" {
  description = "The SSH clone URL of the created repository"
  value       = github_repository.new_repo.ssh_clone_url
}

output "full_name" {
  description = "The full name (owner/name) of the created repository"
  value       = github_repository.new_repo.full_name
}
