---
name: security-review
description: Security review for auth, authorization, secrets, injection, crypto, dependency misuse, and unsafe data exposure.
license: MIT
---

## Purpose

Security review for auth, authorization, secrets, injection, crypto, dependency misuse, and unsafe data exposure.

## Review focus

- auth/authz bypass
- secret leakage
- injection
- unsafe deserialization
- weak crypto
- PII exposure
- dependency CVE impact

## Method

1. Inspect changed files and diff hunks relevant to this skill.
2. Use repository-native tools when available.
3. Prefer exact evidence from changed code.
4. Emit findings using the shared JSONL finding contract.
5. Avoid style-only comments unless they create maintainability or correctness risk.

## Tooling hints

- Use `grep` or editor search before opening files.
- Use `git`, `grep`, and `gh` CLI. These are universally available and sufficient for all review tasks.
- Do not depend on tools beyond `git`, `grep`, `cat`, `head`, `wc`, and `gh`.
