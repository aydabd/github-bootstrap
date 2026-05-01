---
applyTo: "**/*"
---

# Prompt Quality Instruction

When a task is unclear, overloaded, or likely to cause iteration loops, first rewrite it into an execution-ready prompt.

Use this compact structure:

```text
Role:
Task:
Context:
Constraints:
Expected output:
Validation:
Acceptance criteria:
Do not:
```

Keep the rewritten prompt short and specific.

Ask questions only when missing information blocks safe execution. Otherwise, proceed with explicit assumptions.

Prefer exact files, exact errors, exact commands, and exact acceptance criteria over broad repository context.
