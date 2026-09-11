---
name: agent-operating-loop
description: Use at the start of every agent session, issue, bug investigation, review, merge, parallel-work batch, and handoff.
---

# Deterministic Agent Operating Loop

The live GitHub Project and Issue state is authoritative. The repository
manifest at `.github/config/agent-workflow.json` is the schema and capability
contract. Do not create a second planning system in repository files.

## Required Superpowers

Use every required Superpowers skill declared by the manifest. Before any
implementation action, verify that the required plugin is installed and that
the selected skill can be loaded. If it is unavailable, stop with `FAIL` and
report the exact plugin/source/install action. Never silently substitute an
ad-hoc workflow.

## Lifecycle gates

| Gate                  | Required skill                                    | Evidence                                   |
| --------------------- | ------------------------------------------------- | ------------------------------------------ |
| Start and orient      | `using-superpowers`                               | profile, repository, branch, Project state |
| Select work           | `roadmap-prioritization`                          | ranked issue JSON                          |
| Refine issue          | `backlog-breakdown`                               | complete issue contract                    |
| Understand and design | `brainstorming`                                   | approved issue design                      |
| Plan                  | `writing-plans`                                   | ordered Issue checklist                    |
| Isolate               | `using-git-worktrees`                             | branch/worktree mapping                    |
| Implement             | `test-driven-development`                         | observed red, green, refactor              |
| Debug                 | `systematic-debugging`                            | evidence and root cause                    |
| Parallelize           | `dispatching-parallel-agents`                     | dependency/file-overlap JSON               |
| Review                | `requesting-code-review`, `receiving-code-review` | resolved or justified comments             |
| Verify                | `verification-before-completion`                  | machine-readable test evidence             |
| Finish                | `finishing-a-development-branch`                  | merge, cleanup, and handoff state          |

## Start and selection

1. Confirm the active Muximate profile and repository path.
2. Read `AGENTS.md`, `WORKTREES.md`, this skill, and the selected Issue.
3. Read the live Project fields, parent/child links, blockers, required checks,
   and linked pull requests.
4. Check branch, worktrees, status, and `origin/main`.
5. Do not select new feature work while required checks fail unless the Issue
   records an explicit release exception.
6. Rank work in this order: security/production incident, core blocker,
   structural defect prevention, failing required evidence, committed release
   work, maintenance, then new features.
7. Select one issue or independent issues only after checking dependencies and
   actual file/module overlap. Emit the ranking and decision as JSON.

## Issue contract

Before coding, the Issue must contain the problem/evidence, observable
acceptance criteria, scope, non-goals, dependencies, test layer, exact
validation commands, risks, and definition of done. Improve the Issue first
when any part is missing. Keep ordered implementation tasks in the Issue.

## Build and verify

- Use one worktree and branch per Issue/checklist item.
- Write and run a failing test before production behavior code.
- Use the lowest test layer that proves the behavior; required E2E tests must
  explain why browser-level verification is necessary.
- Required tests must not be skipped, retried into green, or conditionally
  passed.
- Prefer JUnit/JSON reports and query them before reading raw logs.
- Before completion, inspect live CI conclusions and every review comment.
- Never claim completion from a diff alone.

## Process improvement

After every issue, bug, failed check, review, or merge, record one reusable
process improvement in an Issue, skill, template, or enforceable check, or
record explicit JSON evidence that no reusable improvement was needed. Do not
create retrospective planning documents.

## Handoff JSON

Every handoff must report `schema_version`, main SHA, worktree/branch state,
completed Issue/PR, fresh validation counts, unresolved failure classes, next
ranked issue and rationale, parallel capacity, and the process refinement.
