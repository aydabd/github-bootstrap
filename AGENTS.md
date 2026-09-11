# Repository Agent Instructions

This is the canonical entrypoint for all coding agents. Shared project
instructions are maintained in:

@.github/instructions/project.instructions.md

The canonical isolated-work and stacked-PR workflow is:

@WORKTREES.md

Edit those canonical files instead of copying their contents into `CLAUDE.md`,
Copilot instructions, or provider-specific agent files. Read the relevant
`.github/skills/` skill before performing a covered workflow.

## Agent operating loop

For every session, issue, review, merge, or handoff, read and follow
`templates/.github/skills/agent-operating-loop/SKILL.md`. The same skill is
installed into generated repositories. Superpowers is required; if the
required plugin is unavailable, stop and report the installation requirement.

GitHub Issues and the live GitHub Project are the source of truth for work
contracts, priority, readiness, dependencies, and parent/child relationships.
Do not create local planning or specification files for normal implementation
work. Use the machine-readable contract in
`templates/.github/config/agent-workflow.json` and emit verification evidence
as deterministic JSON.

The bootstrap repository must dogfood the same issue-first, project-driven
workflow that it generates. Repository-specific setup commands and security
rules remain in the project instructions; lifecycle rules are not duplicated.
