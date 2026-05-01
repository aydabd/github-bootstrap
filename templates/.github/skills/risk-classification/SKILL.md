---
name: risk-classification
description: Classify PR risk and select which specialist reviewers should run based on changed files, diff shape, and risk hints.
license: MIT
---

## Risk levels

- `low`: docs, tests, isolated refactor, no production path.
- `medium`: normal feature/fix, internal API change, moderate logic change.
- `high`: auth, money, PII, DB migration, public API/event contract, infra, deployment, concurrency.
- `critical`: secrets exposure, destructive migration, security boundary, production incident fix.

## Output

```json
{
  "risk": "high",
  "changed_domains": ["backend", "api-contract", "tests"],
  "agents_to_run": [
    "security-reviewer",
    "api-contract-reviewer",
    "test-reviewer",
    "pr-review-auditor"
  ],
  "reason": "Controller and OpenAPI schema changed."
}
```
