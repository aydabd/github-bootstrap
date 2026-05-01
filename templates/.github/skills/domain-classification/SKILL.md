---
name: domain-classification
description: Map changed files to technical domain categories for routing to the correct specialist reviewers.
license: MIT
---

## Domain mapping rules

| File pattern                                 | Domain          |
| -------------------------------------------- | --------------- |
| `*.go`, `*.java`, `*.py`, `*.ts` (non-test)  | backend         |
| `*_test.*`, `*.spec.*`, `**/test/**`         | tests           |
| `*.tsx`, `*.jsx`, `*.css`, `*.scss`          | frontend        |
| `*.sql`, `**/migrations/**`                  | database + data |
| `**/terraform/**`, `*.tf`, `*.k8s.yaml`      | infra           |
| `.github/workflows/**`, `*.ci.yml`           | ci-cd           |
| `**/openapi*`, `**/proto/**`, `**/asyncapi*` | api-contract    |
| `go.mod`, `package.json`, `requirements.txt` | dependency      |
| `*.md`, `CHANGELOG*`, `README*`              | docs-content    |

## Rules

- A file can belong to multiple domains.
- Test files belong to `tests`; do not also classify them as `backend`.
- Overlap between `database` and `data` is intentional — both reviewers apply.
- When uncertain, prefer including a domain over excluding it.

## Output

Compact JSON with `domains` map and `recommended_agents` list.
