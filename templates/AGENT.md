# OpenAI Codex Agent Instructions

## Single source of truth

### OpenAI Codex imports

canonical file below via the `@` directive.

@.github/instructions/project.instructions.md

## Shared Agent Kit

This repository includes reusable PR review agents under `.github/agents/` and
specialised skills under `.github/skills/`.

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

Use the `prompt-gate` skill when a request needs to be rewritten into an execution-ready prompt before implementation.
