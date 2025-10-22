# github-bootstrap

Bootstrap new GitHub repositories with best practices, SOLID principles, and language-agnostic templates.

## What It Does

Creates fully configured repositories with:
- Team-based code ownership
- Branch protection rules
- Dependabot configuration
- Development and production environments
- Documentation templates
- Editor and git configurations
- Super-Linter workflow with auto-fix for PRs
- Makefile for local linting with Docker

## Quick Start

1. Use this template or fork this repository
2. Go to **Actions** → **Create Bootstrap Repository**
3. Click **Run workflow**
4. Enter repository name (required)
5. Configure optional settings
6. Run

Your new repository is created with all templates and settings.

## Workflow Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `repo_name` | Yes | - | New repository name |
| `repo_owner` | No | Current user | Repository owner (user/org) |
| `repo_description` | No | Auto-generated | Repository description |
| `visibility` | No | `private` | Repository visibility (private/public) |
| `enable_branch_protection` | No | `true` | Enable branch protection rules |
| `team_name` | No | `@team-leads` | GitHub team for code owners |
| `license_holder` | No | Current user | License copyright holder |
| `primary_language` | No | `multi-language` | Primary programming language for super-linter |

## What Gets Created

### Configuration Files
Editor configurations, git settings, and ignore patterns that work across all languages and tools.

### GitHub Configuration
Code ownership rules, automated dependency updates, and branch protection settings requiring 2 approvals and code owner reviews.

### Documentation Templates
Project README and AI assistant instructions (Agent, Claude, Copilot) following SOLID, TDD, and DDD principles.

### Super-Linter Integration
- **GitHub Actions workflow** - Auto-formats code on pull requests and commits fixes back to the PR branch
- **Language-agnostic linting** - Always validates Markdown, YAML, JSON, XML, and EditorConfig
- **Programming language support** - Configurable via dropdown menu (JavaScript, TypeScript, Python, Java, Go, Rust, Ruby, PHP, C#, C++, or multi-language)
- **Local linting** - Makefile with `make lint` and `make lint-fix` commands using Docker
- **.super-linter.env** - Configuration file to enable/disable specific language linters

### Repository Settings
- Squash merge only
- Delete branches after merge
- Auto-merge enabled
- Dev environment (no wait, no review)
- Prod environment (30s wait, reviews required)

## Core Principles

All templates follow:
- **SOLID principles** - Maintainable architecture
- **Test-Driven Development** - Everything testable
- **Domain-Driven Design** - Clear business logic
- **Language-agnostic** - Works with any programming language
- **Type safety** - Strict typing enforced
- **Code formatting** - 4 spaces (code), 2 spaces (config)
- **No trailing whitespace** - Clean code standards

## Customization

All templates are in the `templates/` directory. Modify them to match your team's needs:
- Update team names and ownership rules
- Adjust branch protection requirements
- Add or remove documentation templates
- Configure additional dependabot ecosystems
- Change merge strategies
- Modify environment settings
- Customize super-linter configuration in `.super-linter.env`
- Adjust language-specific linting rules

## How It Works

The workflow:
1. Creates new repository via GitHub API
2. Copies all template files from `templates/` directory
3. Updates placeholders (team names, year, copyright holder)
4. Configures super-linter based on selected programming language
5. Configures repository settings
6. Sets up environments and branch protection
7. Commits everything to the new repository

## Requirements

- GitHub personal access token with repo permissions
- Team names must exist in your organization
- Docker installed for local linting with `make lint` (optional)

## License

MIT
