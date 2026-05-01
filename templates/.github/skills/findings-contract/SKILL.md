---
name: findings-contract
description: Defines the compact JSONL finding schema used by all PR specialist agents and the review auditor.
license: MIT
---

# Finding Output Contract

All reviewer agents must return compact JSONL findings. One finding per line.

```jsonl
{
  "id": "SEC-001",
  "agent": "security-reviewer",
  "severity": "blocking",
  "category": "security",
  "file": "src/auth/token.ts",
  "line": 42,
  "title": "Access token is logged",
  "evidence": "The changed code writes accessToken to structured logs.",
  "recommendation": "Remove the token from logs or mask it before logging.",
  "confidence": "high"
}
```

## Required fields

| Field            | Values                                                   |
| ---------------- | -------------------------------------------------------- |
| `id`             | Stable per agent run, prefix by category, e.g. `SEC-001` |
| `agent`          | Agent name                                               |
| `severity`       | `blocking`, `non_blocking`, `note`                       |
| `category`       | Review category                                          |
| `file`           | Relative path, or empty string for repo-level finding    |
| `line`           | Integer line number or null                              |
| `title`          | Short finding title                                      |
| `evidence`       | Concrete evidence from diff/file/tool output             |
| `recommendation` | Minimal actionable recommendation                        |
| `confidence`     | `high`, `medium`, `low`                                  |

## Noise rules

- Do not emit low-confidence style opinions.
- Do not repeat findings already covered by another category if obvious.
- Prefer one precise blocking finding over many weak findings.
- A finding is blocking only when the PR should not merge as-is.
