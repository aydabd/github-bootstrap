---
applyTo: "**"
---

# GitHub Bootstrap — AI Agent Instructions

> **Single source of truth** for all AI coding agents working on this repository.

## Project Overview

GitHub Bootstrap is a Terraform + template repository that creates new GitHub
repositories with standardised structure, CI/CD, linting, and AI agent support.

```text
templates/               # Files copied to new repos (agents, skills, instructions)
terraform/               # Terraform config for repo creation
.github/                 # CI/CD workflows for this repo
scripts/                 # Utility scripts (sync-skills.sh)
```

## Golden Rules

1. **Simplicity** — simplest working solution wins.
2. **Templates are the product** — every file under `templates/` ships to new repos.
3. **Single source of truth** — skills live in `.github/skills/`, symlinked to `.claude/skills/`.
4. **Zero-install agents** — agents must work with only `git`, `grep`, `gh`, and standard POSIX tools.
5. **Lint before commit** — `LINT_MODE=check make lint` must pass.

## Code Style

- Follow language idioms and standard formatting tools.
- Keep functions small and focused (max 50 lines).
- Use meaningful variable names; avoid abbreviations.
- Handle errors explicitly — never ignore them.
- **Formatting**: 2 spaces for YAML/JSON, 4 spaces for shell scripts.
- No trailing whitespace.

## Template Rules

- `templates/.github/skills/` is the canonical source for all skills.
- `templates/.claude/skills/` contains symlinks only — run `scripts/sync-skills.sh` after adding skills.
- Agent files in `.github/agents/` and `.claude/agents/` have different frontmatter and must be maintained separately.
- Template files use `{{REPOSITORY_NAME}}` and `{{REPOSITORY_OWNER}}` placeholders.

## What to Avoid

- Third-party tool dependencies in agent/skill files (`jq`, `yq`, `tokei`, `semgrep`)
- Features added "just in case"
- Hardcoded repository names or paths in templates
- Breaking the symlink contract between `.github/skills/` and `.claude/skills/`
- Silently ignoring errors
