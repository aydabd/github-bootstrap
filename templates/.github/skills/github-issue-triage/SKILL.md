---
name: github-issue-triage
description: Use when creating, classifying, deduplicating, prioritizing, or linking GitHub issues.
---

# GitHub Issue Triage

Treat the issue as the source of truth for one piece of work. Search for
duplicates before creating one. Use a focused title, problem and context,
acceptance criteria, scope boundaries, validation evidence, and links to
related issues or PRs.

Apply existing repository labels and project fields consistently. Do not
invent labels or silently change priority. If the repository has a configured
GitHub Project, update its live Status, Priority, Target release, Area, Size,
and parent or blocking relationships. Do not create or mutate a project unless
the user explicitly requested setup and the required permission is available.

When an issue is too large to implement safely, use `backlog-breakdown` before
assigning it to implementation.

Before concluding that GitHub authentication is invalid, distinguish sandbox
connectivity from credential state. Verify the active `personal` profile, then
retry `gh auth status`, `gh api user`, and the intended issue operation with
network-enabled execution when the sandbox reports connection failures. Only
ask the user to re-authenticate after a network-enabled request reaches GitHub
and returns an authentication error.
