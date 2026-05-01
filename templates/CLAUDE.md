# Claude Instructions

## Single source of truth

### Claude Code imports

- the canonical file below via the @ directive.

@.github/instructions/project.instructions.md

## Shared Agent Kit

This repository includes reusable PR review agents under `.claude/agents/` and reusable skills under `.claude/skills/`.

### Main commands

```text
full review
quick review
security review
test review
resolve PR comments
select tests for this PR
```

### Prompt optimization

Use the `prompt-gate` skill when a task should be rewritten into a compact, execution-ready prompt before implementation.
