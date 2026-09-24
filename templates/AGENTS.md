# Agent Instructions

This file is the canonical entrypoint for agents working in this repository.
Read it at the start of every session, then read the live GitHub Project and
selected Issue before changing files.

## Required capability

Superpowers is required for this workflow. The required plugin and skills are
declared in `.github/config/agent-workflow.json`. If the plugin is unavailable,
stop and report a machine-readable `FAIL` with the exact installation action.
Do not silently skip, replace, or reimplement a Superpowers skill.

## Source of truth

GitHub Issues are the work contract. The GitHub Project is the source of truth
for priority, readiness, release, ownership, dependencies, and parent/child
relationships. Do not create local planning or specification files for normal
implementation work.

Before selecting work, use the live Project's `Ready to work` and `Epics`
views, read the complete issue, inspect blockers and required checks, and emit
the selected issue and evidence as JSON.

## Operating loop

Use `.github/skills/agent-operating-loop/SKILL.md` for every session, issue,
bug investigation, review, merge, parallel-work batch, and handoff. It binds
the lifecycle to the required Superpowers skills and defines the JSON evidence
contract.

Issue templates, project fields, and project views are declared by the
machine-readable workflow manifest. Keep repository-specific commands,
test layers, release gates, security rules, and provider configuration in the
repository adapter; do not fork the lifecycle.
Before PR handoff, complete the closeout gate by reconciling the Issue, linked
PR, Project state, fresh validation evidence, and deterministic handoff JSON.

Before PR handoff, write deterministic evidence JSON and run:

```bash
.github/scripts/validate-agent-closeout.sh \
  --repository OWNER/REPOSITORY \
  --evidence-file PATH/TO/closeout-evidence.json
```

The evidence must include `issue.acceptance_complete`, the linked PR number and
base branch, `project.fields` with every required Project field, fresh
validation counts, and the handoff/process-refinement data. A non-zero result
or any missing required evidence blocks handoff.

Required skill resolution is fail-closed: resolve repository lifecycle skills
from the repository skill catalog at `.github/skills/` before checking the
external Superpowers plugin. Never declare a required skill missing until both
sources have been checked and the repository workflow validator has been run.

## Language and security

Repository content, Issues, pull requests, commits, and agent reports are in
English. Never include secrets, tokens, private keys, or credential values in
source, logs, issue comments, or JSON evidence.
