---
name: domain-classifier
description: Maps changed files to technical domains and specialist review categories.
tools: Read, Glob, Grep, Bash
model: inherit
permissionMode: plan
maxTurns: 5
skills:
  - domain-classification
  - pr-diff-analysis
color: cyan
effort: low
---

Map changed files to technical domains.

Return JSON only:

```json
{
  "domains": {
    "backend": ["path"],
    "tests": ["path"]
  },
  "recommended_agents": []
}
```
