# github-bootstrap

[![Quality](https://github.com/aydabd/github-bootstrap/actions/workflows/quality.yml/badge.svg)](https://github.com/aydabd/github-bootstrap/actions/workflows/quality.yml)

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
- Profiled quality workflow for PR and push (embedded or user-owned centralized delivery)
- AI code review with CodeRabbit and Claude (see [AI Code Review](#ai-code-review))
- Makefile for local quality checks (`make quality ENV_MANAGER=...`)
- SECURITY.md and CONTRIBUTING.md
- CodeQL security scanning workflow (language-aware)
- Vulnerability alerts and Dependabot security updates enabled automatically

## Setup

Recommended: use a **tenant-installed GitHub App** (safer, short-lived installation tokens).

### GitHub App setup

1. Create or use an existing GitHub App with the following minimum permissions:

   | Permission scope              | Level          | Required for                                            |
   | ----------------------------- | -------------- | ------------------------------------------------------- |
   | `Contents`                    | Read and write | Clone template, push initial commits                    |
   | `Administration`              | Read and write | Configure settings, environments, rulesets, and cleanup |
   | `Metadata`                    | Read-only      | Read repository info (auto-granted)                     |
   | `Organization administration` | Read and write | Create repositories in the target organization          |
   | `Issues`                      | Read and write | Create and update repository labels                     |

   The weekly tooling workflow additionally requires `Pull requests` write permission when
   App-authenticated weekly PR creation and auto-merge are enabled.

   For **organization** repositories also add:

   | Permission scope | Level     | Required for                          |
   | ---------------- | --------- | ------------------------------------- |
   | `Members`        | Read-only | Resolve org membership for team setup |

2. Install the App in each target organization (tenant isolation), or authorize it for the
   personal account that will own a personal repository. The `app_owner` value must match the
   target owner.
3. In the repository that runs bootstrap, set:
   - `BOOTSTRAP_APP_PRIVATE_KEY` (protected Actions secret — required for organization installation-token mode)
   - `BOOTSTRAP_APP_USER_TOKEN` (protected reusable-workflow secret — required for personal-account mode; must be the `ghu_` GitHub App user token)
4. When running the workflow, provide:
   - `client_id` (the GitHub App client ID, visible in the App's settings)
   - `app_owner` (target organization or personal-account owner)

Organization creation mints a short-lived installation token for that owner. Personal creation uses
the App user access token, verifies its `/user` login against the target owner, and then calls
`/user/repos`. No PAT fallback exists.

> Private keys and user access tokens are accepted only as protected caller secrets. Never put a
> private key, token, PAT, or credential in workflow inputs, generated repositories, or this repository.

**Note:** `internal` visibility is only available for repositories inside a GitHub Organization.

### Production maintenance App setup

Create the separate Maintenance Writer App through GitHub's UI using the
checked-in manifest:

```bash
scripts/github-setup/github-app-manifest.sh start repository-maintenance-writer
```

Open the printed URL, approve the App creation, install it only on the
maintenance repositories, and retain the GitHub-generated private key in a
protected local file. In the `production-maintenance` GitHub Environment, set
`BOOTSTRAP_APP_CLIENT_ID` and
`BOOTSTRAP_MAINTENANCE_WRITER_APP_SLUG` as variables and
`BOOTSTRAP_APP_PRIVATE_KEY` as a secret. The weekly workflow is explicitly
bound to that Environment. Use separate Environments for other deployments;
the credential names remain stable while Environment scope and protection
rules control access.

The Writer App must remain separate from the Provisioner, Reviewer, and E2E
Admin Apps. Never commit or print its private key.

### Personal App Manifest E2E setup

For a disposable personal-account E2E, create the App through GitHub's App Manifest flow. GitHub
generates the private key during conversion; do not generate one locally:

```bash
credential_dir="$HOME/.local/state/github-bootstrap"
scripts/github-setup/github-app-manifest.sh start repository-bootstrap-provisioner
# Open the printed URL, approve the App, and copy the one-time conversion code.
scripts/github-setup/github-app-manifest.sh convert CODE "$credential_dir"
```

The conversion command writes GitHub's private key, client ID, and client secret only under the
0700 output directory, with each file set to 0600. The example keeps that directory outside the
repository checkout; remove it after setup. Use the App client ID and secret to authorize the
personal account, then exchange the callback code:

```bash
credential_dir="$HOME/.local/state/github-bootstrap"
redirect_uri="https://github.com/settings/apps/new"
scripts/github-setup/github-app-user-token.sh url CLIENT_ID OWNER "$redirect_uri" STATE
APP_CLIENT_SECRET_FILE="$credential_dir/app-client-secret" \
APP_REDIRECT_URI="$redirect_uri" \
  scripts/github-setup/github-app-user-token.sh exchange CLIENT_ID CODE OWNER "$credential_dir/app-user-token"
scripts/github-setup/install-app-secrets.sh OWNER/github-bootstrap \
  "$credential_dir/app-client-id" \
  "$credential_dir/app-private-key.pem" \
  "$credential_dir/app-user-token"
```

The installer sets `BOOTSTRAP_APP_CLIENT_ID` as a repository variable and installs only
`BOOTSTRAP_APP_PRIVATE_KEY` and the verified `BOOTSTRAP_APP_USER_TOKEN` as repository secrets. It
never accepts a PAT or passes credentials through workflow-dispatch inputs. Run
`Test Personal GitHub App E2E` with the personal owner; it creates and cleans up only the two
repositories named for that run. Organization installation-token E2E remains pending without a
disposable organization.

After the disposable E2E, remove the repository configuration and revoke or rotate the App
credentials. This deletes the stored values without exposing them:

```bash
gh secret delete BOOTSTRAP_APP_PRIVATE_KEY --repo OWNER/github-bootstrap --confirm
gh secret delete BOOTSTRAP_APP_USER_TOKEN --repo OWNER/github-bootstrap --confirm
gh variable delete BOOTSTRAP_APP_CLIENT_ID --repo OWNER/github-bootstrap --confirm
```

Also revoke the App user authorization and delete or rotate the App private key in GitHub if the
App will not be reused. Remove the external local credential directory afterward.

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
      client_id: ${{ vars.BOOTSTRAP_APP_CLIENT_ID }}
      app_owner: ${{ inputs.repo_owner }}
      allowed_repo_owners: ${{ vars.ALLOWED_REPO_OWNERS }}
      require_cleanup_approval: true
    secrets:
      BOOTSTRAP_APP_PRIVATE_KEY: ${{ secrets.BOOTSTRAP_APP_PRIVATE_KEY }}
      # For personal-account creation, use this App user access token instead.
      BOOTSTRAP_APP_USER_TOKEN: ${{ secrets.BOOTSTRAP_APP_USER_TOKEN }}
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

1. Complete the [Setup](#setup) steps above.
2. Go to **Actions** → **Terraform Create Repository**.
3. Click **Run workflow** and fill in the App client ID, target owner,
   approved-owner allowlist, and repository settings.

See [`terraform/README.md`](terraform/README.md) for full documentation.

Your new repository is created with all templates and settings.

## Setup Existing Repositories

You can also use this repository to configure a repository that already exists.
Existing-repo setup is explicit and opt-in: each action has one responsibility,
and file changes default to a pull request or plan mode instead of silently
overwriting repository content.

### Reusable Setup Entry Points

Copy a launcher example into your launcher repository and replace
`BOOTSTRAP_OWNER`. The launcher files are the copy-paste source of truth for
caller-side inputs, secrets, and `uses:` syntax.

| Use case            | Launcher example                                                                 | Reusable workflow                                                                                    |
| ------------------- | -------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| General setup       | [`examples/launcher-existing-repo.yml`](examples/launcher-existing-repo.yml)     | [`.github/workflows/setup-existing-repository.yml`](.github/workflows/setup-existing-repository.yml) |
| CodeRabbit only     | [`examples/launcher-coderabbit.yml`](examples/launcher-coderabbit.yml)           | [`.github/workflows/setup-coderabbit.yml`](.github/workflows/setup-coderabbit.yml)                   |
| Labels and security | [`examples/launcher-security-labels.yml`](examples/launcher-security-labels.yml) | [`.github/workflows/setup-labels-and-security.yml`](.github/workflows/setup-labels-and-security.yml) |
| Agent instructions  | [`examples/launcher-agent-templates.yml`](examples/launcher-agent-templates.yml) | [`.github/workflows/setup-agent-instructions.yml`](.github/workflows/setup-agent-instructions.yml)   |

For exact workflow inputs, secrets, and outputs, read the `workflow_call` block in
the reusable workflow file. For capability behavior, read the relevant composite
action metadata under [`.github/actions/`](.github/actions/).

Launcher workflows pass non-secret values as explicit inputs and the private key as a secret from
the launcher repository. Target repository access comes from the resolved GitHub App token.

### Permissions and Authentication

Organization repository creation uses a short-lived GitHub App installation token; personal-account
creation uses a verified GitHub App user access token. See the
[permission-to-endpoint matrix](docs/github-app-permission-matrix.md) for the exact scope rationale.

CodeRabbit setup has one extra prerequisite: install the
[CodeRabbit GitHub App](https://github.com/apps/coderabbitai) on the target
repository. This toolkit can add the config file, labels, and optional ruleset,
but it cannot universally install CodeRabbit for every tenant.

### Local Usage

Local GitHub setup scripts live in [scripts/github-setup/](scripts/github-setup/).
Use that folder's README as the entry point for local setup and live verification
guidance. Each script's `--help` output is the source of truth for command usage.

## Creation Workflows

Creation workflow inputs live in the workflow metadata. Use the workflow files
and launcher examples as the source of truth instead of duplicating input tables
in this README:

- [`.github/workflows/create-repository.yml`](.github/workflows/create-repository.yml)
- [`.github/workflows/terraform-create-repository.yml`](.github/workflows/terraform-create-repository.yml)
- [`examples/launcher-actions.yml`](examples/launcher-actions.yml)
- [`examples/launcher-terraform.yml`](examples/launcher-terraform.yml)

## Architecture Overview

Repository bootstrap now follows a clear separation of responsibilities:

- Orchestrator workflows: `.github/workflows/create-repository.yml` and
  `.github/workflows/terraform-create-repository.yml`
- Shared normalization contract: `tools/pkg/bootstrapinputs` and
  `tools/cmd/bootstrap-inputs`
- Reusable composite actions under `.github/actions/`: `render-precommit-configs`,
  `configure-provider-tooling-files`, `configure-release-tool`, `configure-codeql`,
  `apply-repo-settings`, and `apply-repository-ruleset`
- Manual E2E parity harness: [`.github/workflows/test-repository-creation.yml`](.github/workflows/test-repository-creation.yml)

Use the test workflow's `preset` input to compare Actions and Terraform creation
paths. The preset list lives in the workflow file.

## What Gets Created

### Configuration Files

Editor configurations, Git settings, and ignore patterns that work across all languages and tools.

### GitHub Configuration

Code ownership rules and automated dependency updates. Vulnerability alerts and Dependabot
automated security fixes are enabled on every created repository.

### Documentation Templates

Project readme and AI assistant instructions (Agent, Claude, Copilot) following SOLID, TDD, and DDD principles.

### Quality profiles and delivery

- **Pre-commit hooks** — All quality checks run via `.pre-commit-config.yaml` as the single source of truth
- **Selectable provider** — choose `micromamba`, `mise`, or `system` when creating repositories
- **Config file by provider** — `environment.yml` (micromamba), `mise.toml` (mise), or direct machine tooling (system)
- **Template layout (for maintainers)** — provider assets live in `templates/languages/<language>/providers/<provider>/`
- **Template composition (for maintainers)** — pre-commit source templates live in `templates/languages/*/pre-commit-snippets/` and are rendered by `tools/cmd/precommit-renderer`
- **Root config behavior** — generated root `.pre-commit-config.yaml` follows the first selected language so hooks match the provisioned toolchain
- **Monorepo behavior** — generated `.pre-commit/languages/*.yaml` files are emitted for all selected languages for explicit per-project opt-in
- **One linter per file type** — prettier (JSON/YAML/Markdown), shellcheck + shfmt (shell),
  markdownlint, editorconfig-checker, yamllint, taplo (TOML), terraform fmt
- **Local and CI** — `make quality` auto-fixes locally; `LINT_MODE=check make quality` fails on violations in CI
- **Language-specific linters** — Add language linters to `.pre-commit-config.yaml` as needed
- **Profile manifest** — `templates/.github/config/bootstrap-profile.json` classifies baseline,
  optional planning, and provider-specific assets
- **Embedded delivery** — generated repositories receive local composite actions and reusable workflows
- **Centralized delivery** — generated repositories can reference a user-owned actions/workflows
  repository at a pinned tag or SHA; existing repositories are never migrated automatically

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

Repositories can use two independent AI reviewers that focus on **high and critical issues only** —
no noise from style nitpicks (quality checks handle those).

#### CodeRabbit (GitHub App)

[CodeRabbit](https://coderabbit.ai) can review PRs through its GitHub App:

- **Free tier** — Works out of the box on public/open-source repositories
- **Paid tiers** (Pro / Teams) — Sign up at [coderabbit.ai](https://coderabbit.ai)
  and connect your GitHub organization for private repo support and advanced features
- **Enterprise** — Requires the [CodeRabbit GitHub App](https://github.com/apps/coderabbitai)
  installed on your GitHub Enterprise Server instance; see
  [coderabbit.ai/enterprise](https://coderabbit.ai) for self-hosted deployment options
- **No secrets needed** — Authentication is handled by the GitHub App
- **Configuration** — `.coderabbit.yaml` at the repository root (included in all templates)

Setup: install the [CodeRabbit GitHub App](https://github.com/apps/coderabbitai) on your
repository or organization. Depending on the repository and plan, reviews may start
automatically; for explicit opt-in, run the `Request CodeRabbit Review` workflow and
provide the PR number. The workflow is optional and is not a required status check.
The default ruleset does not guess third-party status-check names. Supply exact
successful check-run names with `--required-status-checks` when applying a
ruleset, or discover them from the target repository first. If CodeRabbit is
rate-limited,
release, Dependabot, and other automation PRs can remain blocked until quota
resets or usage-based reviews are enabled.

#### Claude AI Review (GitHub App + GitHub Actions)

[Claude](https://anthropic.com) provides a second, comment-triggered AI review
layer through the Claude GitHub App and the
`anthropics/claude-code-action` GitHub Action:

- **No static credentials** — Use Anthropic Workload Identity Federation (WIF)
  with GitHub OIDC; do not store API keys or OAuth tokens in repository secrets
- **Repository variables** — Configure `ANTHROPIC_FEDERATION_RULE_ID`,
  `ANTHROPIC_ORGANIZATION_ID`, and `ANTHROPIC_SERVICE_ACCOUNT_ID`
- **Interactive** — Comment `@claude` on any PR to ask follow-up questions
- **Configuration** — `.github/workflows/ai-code-review.yml`

Install the [Claude GitHub App](https://github.com/apps/claude), configure WIF,
and add the workflow to enable Claude reviews. Without the federation variables,
the workflow does not invoke Claude.

The optional [`coderabbit-dependabot-review.yml`](.github/workflows/coderabbit-dependabot-review.yml)
workflow remains because automation-authored PRs can be excluded by CodeRabbit’s
normal App review policy. It uses only the short-lived GitHub Actions token to
post an explicit `@coderabbitai review` request; it does not contain an API key.

#### Review Focus

Both reviewers are configured to flag only high-impact issues:

| Category              | Examples                                                     |
| --------------------- | ------------------------------------------------------------ |
| Security              | Injection, auth bypass, secrets exposure, XSS, CSRF          |
| Bugs                  | Null pointers, off-by-one, race conditions, resource leaks   |
| Critical design flaws | Broken API contracts, missing input validation, SOLID issues |

Style, formatting, and naming concerns are **not** flagged — those are handled by
pre-commit hooks and the quality workflow.

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

### Release Tool Comparison

| Tool           | Stars | Trigger           | Language support | Monorepo | Manual step |
| -------------- | ----- | ----------------- | ---------------- | -------- | ----------- |
| git-cliff      | ~9k   | git tag           | any              | ✅       | `git tag`   |
| release-please | ~7k   | push to main (PR) | language-aware   | partial  | merge PR    |

### Repository Settings

- Squash merge only
- Delete branches after merge
- Auto-merge enabled
- Dev environment (no wait, no review)
- Prod environment (30s wait, reviews required)

### Security

Every bootstrapped repository gets a core security baseline out of the box:

| Feature                      | Details                                                                                           |
| ---------------------------- | ------------------------------------------------------------------------------------------------- |
| Vulnerability alerts         | Enabled automatically via the GitHub API                                                          |
| Dependabot security updates  | Enabled automatically — auto-PRs for vulnerable deps                                              |
| Dependabot version updates   | Configured in `.github/dependabot.yml` for all ecosystems                                         |
| CodeQL scanning              | Workflow generated and scoped to the selected language(s)                                         |
| Branch protection / rulesets | Strict main-branch ruleset with review, signed commits, and optional validated status-check gates |
| SECURITY.md                  | Security policy and vulnerability reporting instructions                                          |
| Secret scanning              | Enabled by GitHub for all public repos automatically                                              |

## Core Principles

All templates follow SOLID principles, TDD, DDD, type safety,
and language-agnostic code formatting (4 spaces code, 2 spaces config).

## AI Agent Instructions

Templates use a **single source of truth** pattern for AI agent instructions:

- **Canonical file**: `.github/instructions/project.instructions.md`
- **Canonical entrypoint**: `AGENTS.md`
- **Canonical isolated workflow**: `WORKTREES.md`
- **Thin pointers**: `CLAUDE.md`, `.github/copilot-instructions.md`
- **Cursor rules**: `.cursor/rules/project.mdc`
- **Windsurf rules**: `.windsurfrules`

Edit only the canonical file — all agents pick up changes automatically.
For worktree and stacked-PR operations, edit `WORKTREES.md` and keep the
`git-worktree-stack` skill as a thin pointer.

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
4. The wrapper workflow then copies template files and configures the selected quality profile

Bootstrap workflows apply the default ruleset payload from
`.github/config/ruleset-default.json` after repository creation.
The default ruleset requires one approving review, approval after the latest
push, resolved review threads, linear history, signed commits, squash-only
pull requests, and the bootstrap-provided `Signed-off-by trailers` and `quality`
checks. When workflows are explicitly reduced, the bootstrap rewrites the
required contexts to match the installed checks. Custom checks must use exact
check-run names validated in the target repository.
CODEOWNERS remains generated
as ownership documentation, but the ruleset does not require code-owner-specific
approval.
Repositories can add CodeRabbit or other checks only after verifying their
exact check-run names in the target repository.
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

- GitHub App credentials: `client_id` plus either the protected installation private key for an
  organization or the protected App user access token for a personal account
  — see [Setup](#setup)
- One of: `micromamba`, `mise`, or system-installed tooling for local quality checks with `make quality`

## Breaking change in issue #78

The generated `lint.yml` workflow and `lint` required status check are removed.
New repositories use the stable `quality` workflow and may select embedded or
user-owned centralized reusable workflows. Existing repositories are not
modified automatically; users choose and perform any manual migration.

## License

MIT
