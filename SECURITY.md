# Security Policy

## Supported Versions

| Version | Supported |
| ------- | --------- |
| Latest  | ✅        |

## Reporting a Vulnerability

Please **do not** report security vulnerabilities through public GitHub issues.

Instead, use one of these channels:

1. **GitHub Security Advisories** (preferred) — Go to the repository's
   [Security tab](security/advisories/new) and click **Report a vulnerability**.
2. **Email** — Contact the repository maintainers listed in [CODEOWNERS](.github/CODEOWNERS).

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Impact assessment
- Suggested fix (if available)

### What to Expect

- Acknowledgement within 48 hours
- Status update within 7 days
- Coordinated disclosure after a fix is available

## Security Practices

This repository follows these security practices:

- Dependencies are kept up to date via [Dependabot](.github/dependabot.yml)
- Vulnerability alerts and automated security fixes are enabled
- All PRs require code-owner review before merging
- Branch protection prevents force-pushes and deletion of `main`
- GitHub secret scanning is available where supported by repository visibility and GitHub/org settings
- Pre-commit hooks lint code, shell scripts, YAML, and Terraform on every commit and PR
- Conventional commits enforce traceable, reviewable changes
