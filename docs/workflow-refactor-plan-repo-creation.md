# Repository Creation Workflow Refactor Plan

## Objective

Simplify repository creation flows by reducing branching logic, centralizing input normalization, and making execution paths explicit and composable.

Primary outcomes:

- fewer large shell blocks with nested `if`/`case`
- single source of truth for language/runtime normalization
- clearer user intent to behavior mapping
- easier testability for branch/tag and provider/language combinations

## Current Problems

1. Input normalization is duplicated across multiple workflows and shell blocks.
2. Language handling has multiple interpretation points (`FIRST_LANG`, aliases, `all`, agnostic).
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

Create one canonical normalization/validation implementation in Go:

- location: `tools/cmd/bootstrap-inputs` (new)
- modes:
  - `validate` (exit code + machine-readable errors)
  - `normalize` (JSON outputs: normalized language set, root language dir, runtime pins)
- workflows consume this output instead of reimplementing shell parsing.

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
- root toolchain/root pre-commit derived from normalized root language selection policy (documented once)
- unsupported language tokens fail early
- aliases (`node`, `nodejs`, `javascript`) normalize deterministically

### 5) Test harness workflow improvements

Keep `test-repository-creation.yml` as manual `workflow_dispatch` only, but align with production behavior:

- input parity with create workflows
- explicit `target_workflow` and `target_ref`
- robust run matching by trigger timestamp + actor + workflow id
- artifact summary of validation checks

## Phased Execution

### Phase 0: Baseline and guardrails

1. Freeze behavior with tests for current accepted inputs.
2. Add snapshot tests for generated key files.
3. Document behavior contract in one markdown file.

Exit criteria:

- green CI
- baseline snapshots committed

### Phase 1: Canonical input normalization

1. Implement `tools/cmd/bootstrap-inputs`.
2. Migrate `create-repository.yml` to consume it.
3. Migrate `terraform-create-repository.yml` to consume it.
4. Remove duplicated shell parsing blocks.

Exit criteria:

- no language parsing logic duplicated in workflow shell blocks
- all input validation sourced from one binary

### Phase 2: Extract composite actions

1. Move pre-commit rendering to `render-precommit-configs` action.
2. Move provider file selection/substitution to `configure-provider-tooling-files` action.
3. Move release/configuration steps into dedicated actions.

Exit criteria:

- top-level workflows mostly linear and readable
- each extracted action has input/output contract

### Phase 3: Test workflow parity and reliability

1. Align test workflow inputs with create workflow schema.
2. Add deterministic dispatch-run correlation metadata.
3. Add matrix-style manual test presets (docs + dispatch examples).

Exit criteria:

- repeatable manual validation against branch/tag refs
- no ambiguous run polling behavior

### Phase 4: Documentation consolidation

1. Update root README and terraform README with new architecture.
2. Add maintainer guide for adding a language/provider/runtime.
3. Add troubleshooting section with common failure signatures.

Exit criteria:

- one obvious place to update when adding support
- no stale docs referencing removed shell parsing blocks

## Deliverables

1. `tools/cmd/bootstrap-inputs` with tests.
2. New composite actions under `.github/actions/`.
3. Simplified top-level workflows with reduced `if`/`case` density.
4. Updated docs and maintainer playbook.
5. Expanded `test-repository-creation.yml` verification summaries.

## Risks and Mitigations

1. Risk: behavior drift while extracting logic.
   - Mitigation: baseline snapshots + phased migration.
2. Risk: harder debugging across composite actions.
   - Mitigation: strict step summaries and action-level diagnostics.
3. Risk: over-abstraction.
   - Mitigation: YAGNI rule, one responsibility per extraction.

## Suggested Session Prompt (Next Session)

Use this prompt to start the next implementation session:

"Implement Phase 1 of docs/workflow-refactor-plan-repo-creation.md. Build tools/cmd/bootstrap-inputs with validate/normalize modes, migrate both create workflows to consume it, remove duplicate language parsing blocks, and keep behavior equivalent for current supported inputs. Add tests and run full lint."
