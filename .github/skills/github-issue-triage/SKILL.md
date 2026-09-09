---
name: github-issue-triage
description: Use when creating, classifying, deduplicating, prioritizing, or linking GitHub issues.
---

# GitHub Issue Triage

Treat each issue as the source of truth for one piece of work. Search for
duplicates first. Include context, acceptance criteria, scope boundaries,
validation evidence, and links to related issues or pull requests.

Use existing labels and project fields consistently. Do not invent priority or
mutate a project without explicit authorization. Use `backlog-breakdown` for
issues that are too large to implement safely.

Before concluding that GitHub authentication is invalid, distinguish sandbox
connectivity from credential state. Verify the active `personal` profile, then
retry `gh auth status`, `gh api user`, and the intended issue operation with
network-enabled execution when the sandbox reports connection failures. Only
ask the user to re-authenticate after a network-enabled request reaches GitHub
and returns an authentication error.
