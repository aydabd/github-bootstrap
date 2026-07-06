# github-bootstrap

[![Lint](https://github.com/aydabd/github-bootstrap/actions/workflows/lint.yml/badge.svg)](https://github.com/aydabd/github-bootstrap/actions/workflows/lint.yml)

Bootstrap new GitHub repositories with best practices, SOLID principles, and language-agnostic templates.

## What It Does

Creates fully configured repositories with:

- Team-based code ownership
- Branch protection rules
- Dependabot configuration
- Development and production environments
- Documentation templates
- Editor and Git configurations
- Conventional commits enforcement via pre-commit hooks
- Release Please workflow for automated semantic versioning
- Pre-commit linting workflow for PR and push (provider-aware: micromamba, mise, or system)
- AI code review with CodeRabbit and Claude (see [AI Code Review](#ai-code-review))
- Makefile for local linting (`make lint` via selected environment provider)
- SECURITY.md and CONTRIBUTING.md
- CodeQL security scanning workflow (language-aware)
- Vulnerability alerts and Dependabot security updates enabled automatically

## Setup

Recommended: use a **tenant-installed GitHub App** (safer, short-lived installation tokens).
Fallback: use a PAT when App setup is not available.

### Option A — GitHub App (recommended)

1. Create or use an existing GitHub App with the following minimum permissions:

   | Permission scope | Level          | Required for                                   |
   | ---------------- | -------------- | ---------------------------------------------- |
   | `Contents`       | Read and write | Clone template, push initial commits           |
   | `Administration` | Read and write | Create repos, configure settings, delete repos |
   | `Metadata`       | Read-only      | Read repository info (auto-granted)            |

   For **organization** repositories also add:

   | Permission scope | Level     | Required for                          |
   | ---------------- | --------- | ------------------------------------- |
   | `Members`        | Read-only | Resolve org membership for team setup |

2. Install the App in each target user/org (tenant isolation). The App must be installed
   on every `app_owner` value you intend to target.
3. In the repository that runs bootstrap, set:
   - `BOOTSTRAP_APP_PRIVATE_KEY` (Actions secret — the PEM private key of the App)
4. When running the workflow, provide:
   - `app_id` (the numeric App ID, visible in the App's settings)
   - `app_owner` (target tenant owner)

The workflow mints a short-lived installation token for that owner and uses it for all API calls.

> **Organization targets only:** GitHub App installation tokens (server-to-server) cannot
> create repositories under a personal user account — this is a GitHub API constraint.
> The target `repo_owner` must be a GitHub **Organization**.
> For personal user account targets, use the PAT fallback (Option B) instead.

### Option B — PAT (fallback)

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
> so it never appears in plain text in the workflow logs. Masking only prevents the token from
> being printed in logs; the raw workflow input value may still be visible in the run's
> inputs/metadata to anyone who can view the run. Prefer
> [Option A — Repository secret](#option-a--repository-secret-recommended-for-sharedteam-use)
> whenever possible, and if you must use Option B, use a short-lived token with the minimum
> required scopes.

**Note:** `internal` visibility is only available for repositories inside a GitHub Organization.
Use `private` for personal account repositories.

## Quick Start

Choose one of three methods to bootstrap a new repository:

### Option A — Reusable workflow from a user-owned launcher (recommended)

> **Copy-paste ready launcher files:** [`examples/launcher-actions.yml`](examples/launcher-actions.yml)
> (Actions) and [`examples/launcher-terraform.yml`](examples/launcher-terraform.yml) (Terraform).
> Copy one into your repo's `.github/workflows/` and replace `BOOTSTRAP_OWNER`.

Create a minimal launcher workflow in your own repo:

```yaml
name: Bootstrap Repository

on:
  workflow_dispatch:
    inputs:
      repo_name:
        required: true
        type: string
      repo_owner:
        required: true
        type: string

jobs:
  bootstrap:
    # Replace {{BOOTSTRAP_OWNER}} with the GitHub user or org that owns this bootstrap repository.
    uses: {{BOOTSTRAP_OWNER}}/github-bootstrap/.github/workflows/create-repository.yml@main
    with:
      repo_name: ${{ inputs.repo_name }}
      repo_owner: ${{ inputs.repo_owner }}
      env_manager: micromamba
      node_version: "24"
      java_version: "25"
      visibility: private
      app_id: ${{ vars.BOOTSTRAP_APP_ID }}
      app_owner: ${{ inputs.repo_owner }}
      allowed_repo_owners: ${{ vars.ALLOWED_REPO_OWNERS }}
      require_cleanup_approval: true
    secrets:
      app_private_key: ${{ secrets.BOOTSTRAP_APP_PRIVATE_KEY }}
```

This example calls the standard Actions bootstrap workflow (`create-repository.yml`).
If you prefer Terraform orchestration, call
`.github/workflows/terraform-create-repository.yml` instead.

> **Cleanup approval environment (required when `require_cleanup_approval: true`):**
> The default is `true`. When enabled, the cleanup gate looks for a `bootstrap-cleanup`
> environment **in your launcher repository** (not in the bootstrap repo).
> Create it before running:
>
> 1. Your repo → **Settings** → **Environments** → **New environment**
> 2. Name: `bootstrap-cleanup`
> 3. Add required reviewers who must approve before a failed repo is deleted
>
> If this environment does not exist and cleanup is triggered, the `cleanup-approval` job
> will fail and the partially-created repository will **not** be deleted automatically.
> Set `require_cleanup_approval: false` to skip approval and delete immediately on failure.

### Option B — Run this repository workflow directly (legacy/simple)

1. Complete the [Setup](#setup) steps above
2. Go to **Actions** → **Create Bootstrap Repository**
3. Click **Run workflow**
4. Enter repository name (required)
5. Configure optional settings
6. Run

### Option C — Terraform IaC

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

| Input                      | Required | Default                                  | Description                                                                                                                                 |
| -------------------------- | -------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `repo_name`                | Yes      | -                                        | New repository name                                                                                                                         |
| `repo_owner`               | No       | Current user/org                         | Repository owner — a GitHub username or organization                                                                                        |
| `repo_description`         | No       | `Repository following SOLID principles…` | Repository description                                                                                                                      |
| `visibility`               | No       | `public`                                 | `public`, `private`, or `internal` (org only)                                                                                               |
| `cleanup_on_failure`       | No       | `true`                                   | Delete the created repository automatically if the workflow fails                                                                           |
| `enable_repo_settings`     | No       | `true`                                   | Apply repo settings PATCH, create dev/prod environments, and enable Dependabot security updates (ruleset application is handled separately) |
| `enable_codeowners`        | No       | `true`                                   | Add a CODEOWNERS file assigning the chosen team as default reviewer                                                                         |
| `workflows`                | No       | `all`                                    | Workflows to include: `all`, `none`, or comma-separated names — `lint`, `codeql`, `ai-code-review`, `release`                               |
| `team_name`                | No       | `team-leads`                             | GitHub team for code owners                                                                                                                 |
| `license_holder`           | No       | Current user/org                         | License copyright holder                                                                                                                    |
| `languages`                | No       | `language-agnostic-only`                 | Comma-separated list of languages (e.g. `javascript,python`) or `all`                                                                       |
| `env_manager`              | Yes      | -                                        | Environment manager: `micromamba`, `mise`, or `system`                                                                                      |
| `python_version`           | No       | `3.13`                                   | Python runtime version used by generated tooling files                                                                                      |
| `node_version`             | No       | `24`                                     | Node.js major LTS version used by generated tooling files                                                                                   |
| `go_version`               | No       | `1.26`                                   | Go stable version used by generated tooling files                                                                                           |
| `java_version`             | No       | `25`                                     | Java LTS version used by generated tooling files                                                                                            |
| `release_tool`             | No       | `git-cliff`                              | Release automation tool: `git-cliff`, `release-please`, or `semantic-release`                                                               |
| `app_id`                   | No       | -                                        | GitHub App ID for App-based authentication (recommended)                                                                                    |
| `app_owner`                | No       | `repo_owner`                             | Owner/user/org whose App installation token is used                                                                                         |
| `allowed_repo_owners`      | No       | -                                        | Optional comma-separated allowlist of owners that can be targeted                                                                           |
| `require_cleanup_approval` | No       | `true`                                   | If `cleanup_on_failure=true`, requires environment approval before delete                                                                   |
| `gh_token`                 | No       | -                                        | PAT fallback input (less safe than secrets or GitHub App)                                                                                   |

## Architecture Overview

Repository bootstrap now follows a clear separation of responsibilities:

- Orchestrator workflows: `.github/workflows/create-repository.yml` and
  `.github/workflows/terraform-create-repository.yml`
- Shared normalization contract: `tools/pkg/bootstrapinputs` and
  `tools/cmd/bootstrap-inputs`
- Reusable composite actions under `.github/actions/`: `render-precommit-configs`,
  `configure-provider-tooling-files`, `configure-release-tool`, `configure-codeql`,
  `apply-repo-settings`, and `apply-repository-ruleset`
- Manual E2E parity harness: `.github/workflows/test-repository-creation.yml`

Use the test harness presets to compare Actions and Terraform creation paths:

- `api-default`
- `terraform-default`
- `api-no-repo-settings`
- `terraform-no-repo-settings`
- `api-all-languages`
- `terraform-all-languages`

## What Gets Created

### Configuration Files

Editor configurations, Git settings, and ignore patterns that work across all languages and tools.

### GitHub Configuration

Code ownership rules and automated dependency updates. Vulnerability alerts and Dependabot
automated security fixes are enabled on every created repository.

### Documentation Templates

Project readme and AI assistant instructions (Agent, Claude, Copilot) following SOLID, TDD, and DDD principles.

### Linting (provider-aware + pre-commit)

- **Pre-commit hooks** — All quality checks run via `.pre-commit-config.yaml` as the single source of truth
- **Selectable provider** — choose `micromamba`, `mise`, or `system` when creating repositories
- **Config file by provider** — `environment.yml` (micromamba), `mise.toml` (mise), or direct machine tooling (system)
- **Template layout (for maintainers)** — provider assets live in `templates/languages/<language>/providers/<provider>/`
- **Template composition (for maintainers)** — pre-commit source templates live in `templates/languages/*/pre-commit-snippets/` and are rendered by `tools/cmd/precommit-renderer`
- **Root config behavior** — generated root `.pre-commit-config.yaml` follows the first selected language so hooks match the provisioned toolchain
- **Monorepo behavior** — generated `.pre-commit/languages/*.yaml` files are emitted for all selected languages for explicit per-project opt-in
- **One linter per file type** — prettier (JSON/YAML/Markdown), shellcheck + shfmt (shell),
  markdownlint, editorconfig-checker, yamllint, taplo (TOML), terraform fmt
- **Local and CI** — `make lint` auto-fixes locally; `LINT_MODE=check make lint` fails on violations in CI
- **Language-specific linters** — Add language linters to `.pre-commit-config.yaml` as needed

To regenerate language template pre-commit files after snippet changes:

```bash
make render-precommit
```

### Weekly Tooling Updates (non-Dependabot)

Dependabot does not cover every tooling surface in this repository. For pinned tooling files
such as `mise.toml`, micromamba `environment.yml`, provider bootstrap binaries, and
pre-commit hook revisions, use:

- `make tooling-update-repo` — update tooling pins for this repository
- `make tooling-update-templates` — update tooling pins under `templates/` for generated repos
- `make tooling-update-all` — run both update paths
- `make tooling-verify` — verify layout assumptions and run updater unit tests before merging changes
- `make tooling-update-micromamba` / `make tooling-update-mise` / `make tooling-update-system` / `make tooling-update-precommit` — run explicit modular updaters

Tooling commands automatically build the updater binary from latest source before execution,
so users and AI agents always run the current implementation.

If Go is not installed on your machine, use `ENV_MANAGER=micromamba` or `ENV_MANAGER=mise`
and `make` will provision Go/tooling for you. `ENV_MANAGER=system` expects host tools to be
already installed.

The updater CLI also supports `--verify-only` for fast offline validation of expected
repository/template layout.
It also supports `--updaters` to run one or more decoupled updater modules.
Implementation lives in the monorepo tools module under `tools/cmd/tooling-updater` + `tools/internal/` + `tools/pkg/` and is built/executed from Make targets.

Automation is provided by `.github/workflows/weekly-tooling-updates.yml`:

- runs weekly and on manual dispatch
- opens or updates one PR with all non-Dependabot tooling updates
- enables PR auto-merge so GitHub merges only after required checks, required approvals,
  and repository merge requirements are satisfied

### Conventional Commits

All repositories enforce [conventional commits](https://www.conventionalcommits.org/)
via pre-commit hooks:

- **Commit format** - `type(scope): description` (e.g., `feat: add login`, `fix(auth): token refresh`)
- **Allowed types** - `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`
- **Enforcement** - Validated by the `conventional-pre-commit` hook on every commit

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
The default ruleset also requires the `CodeRabbit` status check, so CodeRabbit
must be installed and have review quota available. If CodeRabbit is rate-limited,
release, Dependabot, and other automation PRs can remain blocked until quota
resets or usage-based reviews are enabled.

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
pre-commit hooks and the lint workflow.

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

### Security

Every bootstrapped repository gets a core security baseline out of the box:

| Feature                      | Details                                                                                                               |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Vulnerability alerts         | Enabled automatically via the GitHub API                                                                              |
| Dependabot security updates  | Enabled automatically — auto-PRs for vulnerable deps                                                                  |
| Dependabot version updates   | Configured in `.github/dependabot.yml` for all ecosystems                                                             |
| CodeQL scanning              | Workflow generated and scoped to the selected language(s)                                                             |
| Branch protection / rulesets | Default ruleset configured from `.github/config/ruleset-default.json` with review, lint, CodeRabbit, and CodeQL gates |
| SECURITY.md                  | Security policy and vulnerability reporting instructions                                                              |
| Secret scanning              | Enabled by GitHub for all public repos automatically                                                                  |

## Core Principles

All templates follow SOLID principles, TDD, DDD, type safety,
and language-agnostic code formatting (4 spaces code, 2 spaces config).

## AI Agent Instructions

Templates use a **single source of truth** pattern for AI agent instructions:

- **Canonical file**: `.github/instructions/project.instructions.md`
- **Thin pointers**: `AGENT.md`, `CLAUDE.md`, `.github/copilot-instructions.md`
- **Cursor rules**: `.cursor/rules/project.mdc`
- **Windsurf rules**: `.windsurfrules`

Edit only the canonical file — all agents pick up changes automatically.

### PR Review Agent Kit

Every created repository ships with a reusable PR review agent kit:

- **29 specialist agents** under `.github/agents/` and `.claude/agents/`
- **37 skills** under `.github/skills/` (symlinked to `.claude/skills/`)
- Key commands: `full review`, `quick review`, `security review`, `resolve PR comments`
- Agents use only `git`, `grep`, `gh` — no third-party tools required

## Customization

All templates are in `templates/`. Modify them to match your team's needs.
See repository settings, environment configuration, and pre-commit options.

### Maintainer Guide

For adding support to a new language, provider, or runtime version, use:

- [`docs/maintainer-guide-adding-support.md`](docs/maintainer-guide-adding-support.md)

This is the canonical checklist for extension work and validation steps.

### Terraform IaC

The Terraform module (in `terraform/`) manages the same infrastructure declaratively:

1. Creates the repository with all settings via `github_repository`
2. Creates `dev` and `prod` environments via `github_repository_environment`
3. Optionally creates a repository ruleset via `github_repository_ruleset`
   when Terraform input `enable_branch_protection=true`
4. The wrapper workflow then copies template files and configures linting

Bootstrap workflows apply the default ruleset payload from
`.github/config/ruleset-default.json` after repository creation.
The default ruleset requires one approving review, approval after the latest
push, resolved review threads, linear history, the `lint` and `CodeRabbit`
status checks, and CodeQL code scanning results. CODEOWNERS remains generated
as ownership documentation, but the ruleset does not require code-owner-specific
approval.
Because `CodeRabbit` is a required third-party status, repositories using the
default ruleset should install CodeRabbit and monitor review quota. Rate limits
can leave release and dependency automation PRs waiting for the required status.
If you run Terraform directly, you can also manage rulesets through Terraform
inputs (for example, `enable_branch_protection=true`) or configure them
manually in repository settings.

Avoid enabling both approaches for the same repository at the same time.
Applying both the bootstrap default ruleset and Terraform ruleset management
can create overlapping/conflicting rules on `main`.

Terraform provides idempotent applies and state tracking, making it suitable for
managing repositories as long-lived infrastructure.

## Troubleshooting

Common failure signatures and what to check first:

| Failure signature                                                        | Where it appears                   | Likely cause                                               | What to do                                                                                 |
| ------------------------------------------------------------------------ | ---------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `Workflow monitoring timed out` in `test-repository-creation.yml`        | Test workflow monitor step         | Dispatch/run correlation mismatch                          | Confirm `dispatch_actor` is captured from `gh api /user` and actor filtering is enabled.   |
| `Invalid target_ref` / `Invalid workflows` / `Invalid release_tool`      | Test workflow validation step      | Dispatch input outside allow-list                          | Use supported values from workflow inputs or a `preset`.                                   |
| `Missing repository settings payload: .github/config/repo-settings.json` | `apply-repo-settings` action       | Action executed without expected repo checkout/layout      | Ensure bootstrap repository is checked out before running actions and file path is intact. |
| Ruleset step exits with plan/feature warning                             | `apply-repository-ruleset` summary | Target plan does not support rulesets or required features | Upgrade plan/features or accept skip on unsupported targets.                               |
| `Unexpected input` while calling reusable workflow                       | Launcher workflow run              | Caller passes removed/unknown inputs                       | Align caller `with:` block to current inputs in create/terraform workflow definitions.     |

When in doubt, re-run with `test-repository-creation.yml` using the matching
preset for the path you are validating (`api-*` or `terraform-*`).

## Requirements

- Recommended: GitHub App credentials (`app_id` + `BOOTSTRAP_APP_PRIVATE_KEY`) installed in each target tenant owner
- Fallback: GitHub personal access token (PAT) with `repo` scope (add `admin:org` for organization repositories)
  — stored as a `GH_PAT` repository secret **or** provided via the `gh_token` workflow input
  — see [Setup](#setup)
- One of: `micromamba`, `mise`, or system-installed tooling for local linting with `make lint`

## License

MIT
