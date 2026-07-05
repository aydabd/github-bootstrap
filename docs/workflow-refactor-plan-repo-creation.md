# Repository Creation Workflow Refactor Plan

## Review status

This plan remains the right long-term direction, but it is larger than one safe
PR. The current repository already has a Go tooling module under `tools/` and a
`precommit-renderer` command with its own language normalization. That existing
normalization is not yet a safe source of truth for workflow inputs because it
silently falls back to `agnostic` for unknown tokens, while the workflows fail
early for unsupported language values.

Recommended rollout:

1. Start with exact duplicate extraction that does not change behavior.
2. Add characterization tests for the current language/runtime contract.
3. Introduce a shared Go package for normalization and migrate existing tools to
   consume it.
4. Migrate workflows to consume normalized outputs from that package.

The smaller pre-flight validation follow-up can be implemented first as a
low-risk PR, then this refactor can proceed in phases.

## Progress tracking

- Phase 0: In progress. Shared request validation and the behavior contract are
  implemented; baseline renderer and workflow validation tests are started, and
  broader generated-file snapshot coverage still remains.
- Phase 1: Not started. Start after the Phase 0 changes land on `main`.
- Phase 2: Not started. Depends on the normalization contract from Phase 1.
- Phase 3: Not started. Can start after production workflow behavior is stable.
- Phase 4: Not started. Final documentation pass after the implementation phases.

Use the exit criteria under each phase as the source of truth for deciding when a
phase is done. A phase is not complete just because one PR lands; every exit
criterion must be checked or explicitly deferred in the PR description.

## Objective

Simplify repository creation flows by reducing branching logic, centralizing
input normalization, and making execution paths explicit and composable.

Primary outcomes:

- fewer large shell blocks with nested `if`/`case`
- single source of truth for language/runtime normalization
- clearer user intent to behavior mapping
- easier testability for branch/tag and provider/language combinations

## Current Problems

1. Input normalization is duplicated across multiple workflows and shell blocks.
2. Language handling has multiple interpretation points (`FIRST_LANG`, aliases,
   `all`, agnostic).
3. Repository creation workflows mix orchestration and transformation logic.
4. Test workflow polling and matching logic is non-trivial and easy to regress.
5. Adding a new language/provider/runtime requires edits in many places.

## Non-Goals

1. No change to external user-facing workflow names in phase 1.
2. No immediate removal of Terraform-based path.
3. No behavior changes for existing default happy path unless explicitly listed.

## Design Principles

1. Simplicity first: smallest stable abstraction, no speculative frameworks.
2. YAGNI: only factor code that is already duplicated or high-risk.
3. Explicit contracts: each component has clear inputs/outputs.
4. Safe defaults: default values and allowed choices are strongly constrained.
5. Progressive rollout: introduce shared modules first, migrate incrementally.

## Target Architecture

### 1) Orchestrator workflows

- Keep two top-level entry workflows:
  - `create-repository.yml`
  - `terraform-create-repository.yml`
- Limit them to orchestration only:
  - resolve auth
  - call shared action/script units
  - publish summary

### 2) Shared normalization layer

Create one canonical normalization/validation implementation in Go. Prefer a
shared package plus command wrapper rather than duplicating logic inside separate
commands:

- package location: `tools/pkg/bootstrapinputs` (new)
- command location: `tools/cmd/bootstrap-inputs` (new)
- modes:
  - `validate` (exit code + machine-readable errors)
  - `normalize` (JSON outputs: normalized language set, root language dir,
    runtime pins)
- workflows consume this output instead of reimplementing shell parsing
- `tools/cmd/precommit-renderer` consumes the same package instead of keeping its
  own language normalization

The package must preserve the stricter workflow behavior: unsupported language
tokens fail instead of falling back to `agnostic`.

### 3) Reusable composite actions

Introduce composable units under `.github/actions/`:

- `normalize-bootstrap-inputs`
- `render-precommit-configs`
- `configure-provider-tooling-files`
- `configure-release-tool`
- `configure-codeql`
- `apply-repo-settings`
- `apply-branch-protection`

Each action:

- has explicit inputs/outputs
- contains one responsibility
- can be tested independently via workflow tests

### 4) Deterministic language behavior contract

Define and enforce one contract:

- `languages=all` -> full language set for per-language artifacts
- root toolchain/root pre-commit derived from normalized root language selection
  policy (documented once)
- unsupported language tokens fail early
- aliases (`node`, `nodejs`, `javascript`) normalize deterministically

### 5) Test harness workflow improvements

Keep `test-repository-creation.yml` as manual `workflow_dispatch` only, but
align with production behavior:

- input parity with create workflows
- explicit `target_workflow` and `target_ref`
- robust run matching by trigger timestamp + actor + workflow id
- artifact summary of validation checks

## Phased Execution

### Phase 0: Baseline and guardrails

- [x] Extract exact duplicated request validation into small composite actions.
- [ ] Freeze behavior with tests for current accepted inputs.
  - [x] Add pre-commit renderer baseline tests for language aliases and current
        unknown-token drift.
  - [x] Add workflow-level input validation characterization tests.
- [ ] Add snapshot tests for generated key files.
  - [x] Add snapshot-style assertions for pre-commit config generated from real
        language snippets.
  - [ ] Add file snapshots for generated repository key files.
- [x] Document behavior contract in one markdown file.

Exit criteria:

- [x] duplicated allowlist/audit/App-vs-User shell is removed from both creation
      workflows
- [ ] green CI
- [ ] baseline snapshots committed
- [x] current accepted and rejected language/runtime inputs are documented in
      `docs/repository-creation-behavior-contract.md`

### Phase 1: Canonical input normalization

1. [ ] Implement `tools/pkg/bootstrapinputs` with tests covering aliases, `all`,
       `language-agnostic-only`, invalid tokens, runtime pins, root language policy,
       and release type mapping.
2. [ ] Implement `tools/cmd/bootstrap-inputs` as a thin CLI over the package.
3. [ ] Migrate `tools/cmd/precommit-renderer` to use the shared package.
4. [ ] Migrate `create-repository.yml` to consume normalized outputs.
5. [ ] Migrate `terraform-create-repository.yml` to consume normalized outputs.
6. [ ] Remove duplicated shell parsing blocks.

Exit criteria:

- [ ] no language parsing logic duplicated in workflow shell blocks
- [ ] all input validation sourced from one shared Go package
- [ ] unsupported language tokens fail consistently across workflows and tools

### Phase 2: Extract composite actions

1. [ ] Move pre-commit rendering to `render-precommit-configs` action.
2. [ ] Move provider file selection/substitution to
       `configure-provider-tooling-files` action.
3. [ ] Move release/configuration steps into dedicated actions.
4. [ ] Move CodeQL configuration into `configure-codeql` only if the Python helper
       remains a stable boundary.
5. [ ] Move repo settings and branch protection only after the direct and Terraform
       paths have matching behavior documented.

Exit criteria:

- [ ] top-level workflows mostly linear and readable
- [ ] each extracted action has input/output contract

### Phase 3: Test workflow parity and reliability

1. [ ] Align test workflow inputs with create workflow schema.
2. [ ] Add deterministic dispatch-run correlation metadata.
3. [ ] Add matrix-style manual test presets (docs + dispatch examples).

Exit criteria:

- [ ] repeatable manual validation against branch/tag refs
- [ ] no ambiguous run polling behavior

### Phase 4: Documentation consolidation

1. [ ] Update root README and terraform README with new architecture.
2. [ ] Add maintainer guide for adding a language/provider/runtime.
3. [ ] Add troubleshooting section with common failure signatures.

Exit criteria:

- [ ] one obvious place to update when adding support
- [ ] no stale docs referencing removed shell parsing blocks

## Deliverables

1. `tools/pkg/bootstrapinputs` and `tools/cmd/bootstrap-inputs` with tests.
2. New composite actions under `.github/actions/`.
3. Simplified top-level workflows with reduced `if`/`case` density.
4. Updated docs and maintainer playbook.
5. Expanded `test-repository-creation.yml` verification summaries.

## Behavior Contract

Current repository creation behavior is documented in
`docs/repository-creation-behavior-contract.md`. Phase 1 must preserve this
contract or update it deliberately with matching tests.

## Risks and Mitigations

1. Risk: behavior drift while extracting logic.
   - Mitigation: baseline snapshots + phased migration.
2. Risk: harder debugging across composite actions.
   - Mitigation: strict step summaries and action-level diagnostics.
3. Risk: over-abstraction.
   - Mitigation: YAGNI rule, one responsibility per extraction.

## Suggested Session Prompt (Next Session)

Use this prompt to start the next implementation session:

> Implement Phase 0 of `docs/workflow-refactor-plan-repo-creation.md` and
> `docs/follow-up-shared-validation-action.md`. Extract the duplicated
> allowlist, audit, and App-vs-User validation into shared composite actions
> without changing workflow inputs or validation order. Update both repository
> creation workflows, run focused checks, and run
> `LINT_MODE=check make lint`.

After Phase 0 lands, use this prompt for the next normalization PR:

> Implement Phase 1 of `docs/workflow-refactor-plan-repo-creation.md`. Build
> `tools/pkg/bootstrapinputs` and `tools/cmd/bootstrap-inputs` with
> validate/normalize modes, migrate `precommit-renderer` and both create
> workflows to consume the shared normalization, remove duplicate language
> parsing blocks, and keep behavior equivalent for current supported inputs.
> Add tests and run full lint.
