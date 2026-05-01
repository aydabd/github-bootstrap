# GitHub Copilot Instructions

<!-- Single source of truth is .github/instructions/project.instructions.md -->
<!--
  GitHub Copilot (VS Code >= 1.99 / Copilot Chat) automatically loads every
  .github/instructions/*.instructions.md file whose applyTo glob matches the
  current file.  The canonical project instructions live in:

      .github/instructions/project.instructions.md

  This file is kept for backwards-compatibility with older Copilot versions and
  other tools that look specifically for .github/copilot-instructions.md.
  Do NOT duplicate content here - edit the canonical file instead.
-->

@.github/instructions/project.instructions.md

## Copilot Agent Kit

Use the repository agents and skills for PR work.

## PR review

For `full review`, use `pr-full-review-orchestrator`.
For `quick review`, use `pr-quick-review-orchestrator`.
For comment resolution, use `pr-comment-resolver`.
For test selection, use `test-impact-selector`.

## Prompt optimization

When a task is unclear, overloaded, or likely to cause iteration loops, use the `prompt-gate` skill first.

## Rules

- Prefer targeted changed-file analysis over repository-wide scans.
- Specialist reviewers must output JSONL findings or `NO_FINDINGS`.
- Final review must be produced by `pr-review-auditor`.
- Keep inline comments short.
- Fix only valid PR comments.
- Run targeted tests before committing fixes.
