---
name: Domain Classifier
description: Maps changed files to technical domains and specialist review categories.
target: github-copilot
tools:
  - read
  - search
  - execute
disable-model-invocation: false
user-invocable: true
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
