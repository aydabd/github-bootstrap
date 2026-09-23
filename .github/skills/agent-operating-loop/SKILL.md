---
name: agent-operating-loop
description: Use for every github-bootstrap session, issue, review, merge, parallel-work batch, and handoff.
---

# Bootstrap Agent Operating Loop

The canonical lifecycle is shipped in
`templates/.github/skills/agent-operating-loop/SKILL.md` and described by
`templates/.github/config/agent-workflow.json`. Read that file before acting.

The live GitHub Issue is the work contract and the live Project is the source
of truth for priority, readiness, release, dependencies, and parent/child
relationships. Superpowers is required. If the plugin or selected skill is
unavailable, stop with `FAIL` and exact installation instructions.

Use the declared Superpowers gates for discovery, brainstorming, planning,
worktree isolation, TDD, debugging, parallel work, review, verification, and
cleanup. Before PR handoff, complete the closeout gate by reconciling the Issue,
PR, Project, validation, and handoff evidence. Emit selection, test, and
handoff evidence as deterministic JSON.
Do not create local planning/specification files for ordinary implementation.

## Skill resolution

Resolve repository lifecycle skills from the repository skill catalog at
`.github/skills/` before checking the external Superpowers plugin. Never
declare a required skill missing until both sources have been checked and the
repository workflow validator has been run. This applies to the bootstrap
repository and generated repositories.
