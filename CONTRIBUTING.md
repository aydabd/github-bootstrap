# Contributing

Thank you for taking the time to contribute! This document describes the process for reporting
issues, requesting features, and submitting changes.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Developer Certificate of Origin](#developer-certificate-of-origin)
- [Getting Started](#getting-started)
- [Branching Strategy](#branching-strategy)
- [Commit Conventions](#commit-conventions)
- [Pull Request Process](#pull-request-process)
- [Code Standards](#code-standards)
- [Reporting Issues](#reporting-issues)

## Code of Conduct

Be respectful, inclusive, and constructive. Harassment or abusive behaviour will not be tolerated.

## Developer Certificate of Origin

Contributions must comply with the
[Developer Certificate of Origin 1.1](https://developercertificate.org/).
Add a `Signed-off-by: Name <email>` trailer to every commit with `git commit -s`.

## Getting Started

```bash
# 1. Fork the repository, then clone your fork
git clone https://github.com/<your-username>/github-bootstrap.git
cd github-bootstrap

# 2. Create a feature branch (see Branching Strategy below)
git checkout -b feat/your-feature-name

# 3. Make your changes and test locally
make quality     # run quality checks with auto-fix
LINT_MODE=check make quality  # run CI-equivalent check-only quality checks

# 4. Commit using conventional commits (see below)
git commit -m "feat: add new repository setting"

# 5. Push and open a Pull Request
git push origin feat/your-feature-name
```

## Branching Strategy

Branch names must follow this pattern:

| Prefix      | Use for                                   |
| ----------- | ----------------------------------------- |
| `feat/`     | New features or additions                 |
| `fix/`      | Bug fixes                                 |
| `docs/`     | Documentation-only changes                |
| `chore/`    | Maintenance, tooling, or dependency bumps |
| `refactor/` | Refactoring without functional change     |
| `test/`     | Test additions or improvements            |

Examples: `feat/add-codeql-workflow`, `fix/branch-protection-count`, `docs/update-readme`.

## Commit Conventions

All commits must follow [Conventional Commits](https://www.conventionalcommits.org/):

```text
type(scope): short description

[optional body]

[optional footer]
```

### Allowed Types

| Type       | Description                                   |
| ---------- | --------------------------------------------- |
| `feat`     | New feature                                   |
| `fix`      | Bug fix                                       |
| `docs`     | Documentation only                            |
| `style`    | Formatting, whitespace (no logic change)      |
| `refactor` | Refactoring without functional change         |
| `perf`     | Performance improvement                       |
| `test`     | Adding or updating tests                      |
| `build`    | Build system or external dependency change    |
| `ci`       | CI/CD configuration change                    |
| `chore`    | Other maintenance (e.g., update `.gitignore`) |
| `revert`   | Revert a previous commit                      |

### Breaking Changes

Append `!` to the type or add a `BREAKING CHANGE:` footer:

```text
feat!: rename workflow input repo_owner to owner

BREAKING CHANGE: the workflow input `repo_owner` has been renamed to `owner`.
Update any saved workflow dispatch calls accordingly.
```

### Commit Policy Configuration

The pull-request commit policy uses the centralized
`@commitlint/config-conventional` default, so repositories do not need a
commitlint configuration file. A monorepo that needs a local policy can reuse
the same action with a working directory and a config path relative to it:

```yaml
- uses: ./.github/actions/verify-conventional-commits
  with:
    token: ${{ github.token }}
    repository: ${{ github.repository }}
    pull-request-number: ${{ github.event.pull_request.number }}
    working-directory: packages/api
    config-path: commitlint.config.cjs
```

Signed-off-by trailers are checked separately for DCO compliance; a commitlint
configuration override does not change that check.

## Pull Request Process

1. **Branch** from `main` and keep your PR focused on a single concern.
2. **Tests** — add or update tests where applicable.
3. **Quality checks** — run `make quality` and fix any reported issues before opening the PR.
4. **PR title** — use the same conventional commit format as your commits.
5. **Fill in the template** — the PR template guides you through the required information.
6. **Two approvals** are required from code owners before merging.
7. PRs are merged using **squash merge** to keep the history clean.

## Code Standards

- **Indentation**: 4 spaces for code, 2 spaces for YAML/JSON/TOML
- **Line length**: 120 characters max
- **No trailing whitespace**
- **Shell scripts**: must pass `shellcheck` and be formatted with `shfmt`
- **YAML**: validated by `yamllint` / `prettier`
- **Markdown**: validated by `markdownlint` / `prettier`
- **Terraform**: formatted with `terraform fmt` and validated with `tflint`
- **No hardcoded secrets or credentials**

## Reporting Issues

- Use [GitHub Issues](../../issues/new/choose) and select the appropriate template.
- For security vulnerabilities, follow the [Security Policy](SECURITY.md).
- Include as much context as possible: version, steps to reproduce, expected vs. actual behaviour.
