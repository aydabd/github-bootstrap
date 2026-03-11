# github-bootstrap

[![Super-Linter](https://github.com/aydabd/github-bootstrap/actions/workflows/super-linter.yml/badge.svg)](https://github.com/aydabd/github-bootstrap/actions/workflows/super-linter.yml)

Bootstrap new GitHub repositories with best practices, SOLID principles, and language-agnostic templates.

## What It Does

Creates fully configured repositories with:

- Team-based code ownership
- Branch protection rules
- Dependabot configuration
- Development and production environments
- Documentation templates
- Editor and Git configurations
- Conventional commits enforcement via commitlint
- Release Please workflow for automated semantic versioning
- Super-Linter workflow with autofix for PRs
- AI code review with CodeRabbit and Claude (see [AI Code Review](#ai-code-review))
- Makefile for local linting with Docker

## Setup

Before running either workflow you need a GitHub Personal Access Token (PAT). No GitHub App is
required — the PAT alone is sufficient for both personal accounts and organizations.

### 1 — Create a GitHub PAT

1. Go to **GitHub** → **Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
2. Click **Generate new token (classic)**
3. Select the required scopes:

   | Scope         | Required for                                              |
   | ------------- | --------------------------------------------------------- |
   | `repo`        | Create, clone, and push to repositories                   |
   | `admin:org`   | Create repositories inside an organization (org use only) |
   | `delete_repo` | Delete repositories on workflow failure (optional)        |

4. Copy the generated token (starts with `ghp_…`)

### 2 — Provide the PAT to the workflow

There are two ways to supply the token, listed from most to least recommended:

#### Option A — Repository secret (recommended for shared/team use)

1. Fork this repository **or** click **Use this template** → **Create a new repository**
   (for company use, create the fork/template repo inside your organization)
2. Go to your fork → **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `GH_PAT`, Value: your token from step 1
5. Click **Add secret**

The workflows will automatically pick up `GH_PAT` without any extra input.

#### Option B — Workflow input (for users without secret-management access)

If you are working in an enterprise or internal repository where you cannot add repository secrets,
you can pass your token directly when triggering a workflow:

1. Go to **Actions** → select the workflow → **Run workflow**
2. Fill in the **Personal Access Token (gh_token)** field with your `ghp_…` token

> **Security note:** The token is immediately masked with `::add-mask::` at the start of each job
> so it never appears in plain text in the workflow logs.

> **Note:** `internal` visibility is only available for repositories inside a GitHub Organization.
> Use `private` for personal account repositories.

## Quick Start

Choose one of two methods to bootstrap a new repository:

### Option A — GitHub Actions (no local tools required)

1. Complete the [Setup](#setup) steps above
2. Go to **Actions** → **Create Bootstrap Repository**
3. Click **Run workflow**
4. Enter repository name (required)
5. Configure optional settings
6. Run

### Option B — Terraform IaC

1. Complete the [Setup](#setup) steps above
2. Go to **Actions** → **Terraform Create Repository**
3. Click **Run workflow** and fill in the inputs, **or** apply locally:

   ```bash
   cd terraform
   terraform init
   terraform apply \
     -var="github_token=ghp_yourtoken" \
     -var="repo_name=my-new-repo" \
     -var="repo_owner=my-org"
   ```

See [`terraform/README.md`](terraform/README.md) for full documentation.

Your new repository is created with all templates and settings.

## Workflow Inputs

| Input                      | Required | Default                                               | Description                                                                    |
| -------------------------- | -------- | ----------------------------------------------------- | ------------------------------------------------------------------------------ |
| `repo_name`                | Yes      | -                                                     | New repository name                                                            |
| `repo_owner`               | No       | Current user/org                                      | Repository owner — a GitHub username or organization                           |
| `repo_description`         | No       | `Repository following SOLID principles…`              | Repository description                                                         |
| `visibility`               | No       | `public`                                              | `public`, `private`, or `internal` (org only)                                  |
| `cleanup_on_failure`       | No       | `true`                                                | Delete the created repository automatically if the workflow fails              |
| `enable_branch_protection` | No       | `true`                                                | Enable branch protection rules                                                 |
| `team_name`                | No       | `team-leads`                                          | GitHub team for code owners                                                    |
| `license_holder`           | No       | Current user/org                                      | License copyright holder                                                       |
| `languages`                | No       | `language-agnostic-only`                              | Comma-separated list of languages (e.g. `javascript,python`) or `all`          |
| `release_tool`             | No       | `git-cliff`                                           | Release automation tool: `git-cliff`, `release-please`, or `semantic-release`  |

## What Gets Created

### Configuration Files

Editor configurations, Git settings, and ignore patterns that work across all languages and tools.

### GitHub Configuration

Code ownership rules, automated dependency updates, and branch protection settings requiring 2 approvals and code owner reviews.

### Documentation Templates

Project readme and AI assistant instructions (Agent, Claude, Copilot) following SOLID, TDD, and DDD principles.

### Super-Linter Integration

- **GitHub Actions workflow** — Autoformats code on pull requests and commits fixes back to the PR branch
- **One linter per file type** — JSON, YAML, and Markdown each use a single tool to avoid
  rule conflicts and keep runs fast (`VALIDATE_JSON_PRETTIER`, `VALIDATE_YAML_PRETTIER`,
  `VALIDATE_MARKDOWN` + `FIX_MARKDOWN_PRETTIER`)
- **Shell scripts** — shellcheck (correctness) + shfmt (formatting) run as complementary tools
- **Language-specific linters** — Enabled automatically via dropdown when the repository is created;
  commented-out stubs remain in `.super-linter.env` for easy opt-in later
- **Local linting** — Makefile with `make lint` and `make lint-fix` commands using Docker
- **`slim` image** — Only the linters you need; dramatically smaller than the `standard` image

### Conventional Commits

All repositories enforce [conventional commits](https://www.conventionalcommits.org/)
using commitlint integrated with Super-Linter:

- **Commit format** - `type(scope): description` (e.g., `feat: add login`, `fix(auth): token refresh`)
- **Allowed types** - `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`
- **Configuration** - `.commitlintrc.yml` at the repository root
- **Enforcement** - Validated automatically via Super-Linter on every PR and push

### AI Code Review

Every repository gets two independent AI reviewers that focus on **high and critical issues only** —
no noise from style nitpicks (linters handle those).

#### CodeRabbit (GitHub App)

[CodeRabbit](https://coderabbit.ai) reviews every PR automatically via its GitHub App:

- **Free tier** — Works out of the box on public/open-source repositories
- **Paid tiers** (Pro / Teams) — Sign up at [coderabbit.ai](https://coderabbit.ai)
  and connect your GitHub organization for private repo support and advanced features
- **Enterprise** — Requires the [CodeRabbit GitHub App](https://github.com/apps/coderabbitai)
  installed on your GitHub Enterprise Server instance; see
  [coderabbit.ai/enterprise](https://coderabbit.ai) for self-hosted deployment options
- **No secrets needed** — Authentication is handled by the GitHub App
- **Configuration** — `.coderabbit.yaml` at the repository root (included in all templates)

Setup: install the [CodeRabbit GitHub App](https://github.com/apps/coderabbitai) on your
repository or organization. Reviews start automatically on the next PR.

#### Claude AI Review (GitHub Actions)

[Claude](https://anthropic.com) provides a second AI review layer via the
`anthropics/claude-code-action` GitHub Action:

- **API key** — Add an `ANTHROPIC_API_KEY` repository secret from
  [console.anthropic.com](https://console.anthropic.com)
- **Graceful skip** — The workflow is skipped with a notice when no API key is configured,
  so it never breaks CI
- **Interactive** — Comment `@claude` on any PR to ask follow-up questions
- **Configuration** — `.github/workflows/ai-code-review.yml`

#### Review Focus

Both reviewers are configured to flag only high-impact issues:

| Category              | Examples                                                     |
| --------------------- | ------------------------------------------------------------ |
| Security              | Injection, auth bypass, secrets exposure, XSS, CSRF          |
| Bugs                  | Null pointers, off-by-one, race conditions, resource leaks   |
| Critical design flaws | Broken API contracts, missing input validation, SOLID issues |

Style, formatting, and naming concerns are **not** flagged — those are handled by
Super-Linter and pre-commit hooks.

#### Opting Out

Add the `skip-ai-review` label to any PR to skip both AI reviewers for that PR.

### Release Automation

Choose your release automation tool when creating a repository:

#### Option A — git-cliff (default, tag-based)

Lightweight, tag-driven releases powered by [git-cliff](https://git-cliff.org) (~9k ⭐):

- **Tag-based workflow** — Push a version tag (`v1.2.3`) to trigger a release
- **Fast** — Written in Rust; generates changelogs in milliseconds
- **Language-agnostic** — Works for any language without version file management
- **CHANGELOG.md** — Generated from conventional commits, committed back to the default branch
- **GitHub Releases** — Created automatically with the tag's changelog section as release notes
- **Config file** — `cliff.toml` (Tera template for full customisation)

```sh
# Create a release with git-cliff
git tag v1.2.3
git push origin v1.2.3   # triggers the git-cliff-release.yml workflow
```

#### Option B — release-please (PR-based)

Automated PR-based releases powered by [Google's Release Please](https://github.com/googleapis/release-please):

- **Semantic versioning** — Versions bumped automatically from commit types
  (`feat` → minor, `fix` → patch, `feat!`/`BREAKING CHANGE` → major)
- **Language-aware** — Release type set from the selected language (updates `package.json`,
  `Cargo.toml`, `pyproject.toml`, etc.)
- **Release PRs** — Release Please opens a PR that tracks changes and updates the changelog
- **CHANGELOG.md** — Generated automatically from conventional commit messages
- **GitHub Releases** — Created automatically when the release PR is merged
- **Config files** — `release-please-config.json`, `.release-please-manifest.json`

##### Language to Release Type Mapping

| Language Input                          | Release Type       | Version Files Updated                     |
| --------------------------------------- | ------------------ | ----------------------------------------- |
| `javascript`                            | `node`             | `package.json`                            |
| `typescript`                            | `node`             | `package.json`                            |
| `python`                                | `python`           | `pyproject.toml`, `setup.py`, `setup.cfg` |
| `go`                                    | `go`               | Go module tags                            |
| `rust`                                  | `rust`             | `Cargo.toml`                              |
| `java` / `kotlin`                       | `java`             | `pom.xml`                                 |
| `ruby`                                  | `ruby`             | `*.gemspec`, `lib/**/version.rb`          |
| `php`                                   | `php`              | `composer.json`                           |
| `terraform`                             | `terraform-module` | Terraform module tags                     |
| `all` / `language-agnostic-only`        | `simple`           | `CHANGELOG.md` only                       |
| `typescript,python` (multi, first wins) | `node`             | Same as first language (`package.json`)   |

#### Option C — semantic-release (push-to-main, fully automated)

[semantic-release](https://github.com/semantic-release/semantic-release) (~23k ⭐) — the most popular
release automation tool. Zero manual steps: every merge to `main` is analysed and released
automatically.

- **Fully automated** — No tags, no PRs needed; semantic-release decides the version from commits
- **Language-agnostic** — GitHub-releases-only mode works for any language
- **CHANGELOG.md** — Generated and committed back to `main` automatically
- **GitHub Releases** — Created with generated release notes on every merge
- **Config file** — `.releaserc.json` (plugin-based, highly extensible)

```sh
# Nothing to do manually! Just merge to main with conventional commits.
# semantic-release runs on every push to main and auto-tags + releases.
```

### Release Tool Comparison

| Tool             | Stars | Trigger           | Language support | Monorepo    | Manual step |
| ---------------- | ----- | ----------------- | ---------------- | ----------- | ----------- |
| git-cliff        | ~9k   | git tag           | any              | ✅          | `git tag`   |
| release-please   | ~7k   | push to main (PR) | language-aware   | partial     | merge PR    |
| semantic-release | ~23k  | push to main      | any              | via plugins | automatic   |

### Repository Settings

- Squash merge only
- Delete branches after merge
- Auto-merge enabled
- Dev environment (no wait, no review)
- Prod environment (30s wait, reviews required)

## Core Principles

All templates follow SOLID principles, TDD, DDD, type safety,
and language-agnostic code formatting (4 spaces code, 2 spaces config).

## AI Agent Instructions

Templates use a **single source of truth** pattern for AI agent instructions:

- **Canonical file**: `.github/instructions/project.instructions.md`
- **Thin pointers**: `AGENT.md`, `CLAUDE.md`, `.github/copilot-instructions.md`
- **Cursor rules**: `.cursor/rules/project.mdc`

Edit only the canonical file — all agents pick up changes automatically.

## Customization

All templates are in `templates/`. Modify them to match your team's needs.
See repository settings, environment configuration, and super-linter options.

### Terraform IaC

The Terraform module (in `terraform/`) manages the same infrastructure declaratively:

1. Creates the repository with all settings via `github_repository`
2. Creates `dev` and `prod` environments via `github_repository_environment`
3. Applies branch protection via `github_repository_ruleset`
4. The wrapper workflow then copies template files and configures super-linter

Terraform provides idempotent applies and state tracking, making it suitable for
managing repositories as long-lived infrastructure.

## Requirements

- GitHub personal access token (PAT) with `repo` scope (add `admin:org` for organization repositories)
  — stored as a `GH_PAT` repository secret **or** provided via the `gh_token` workflow input
  — see [Setup](#setup)
- Docker installed for local linting with `make lint` (optional)

## License

MIT
