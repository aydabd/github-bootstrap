# Follow-up: Extract shared bootstrap request validation

## Review status

This follow-up is still valid, but the first draft missed two implementation
details in the current workflows:

- The audit step also needs `repo_name`, so the shared unit must accept it as an
  explicit input.
- A single composite action that includes the owner type check must run after
  `resolve-gh-token`, which would move allowlist validation later than it runs
  today. To preserve current fail-fast behavior for disallowed owners, split the
  extraction into two composite actions.

Recommended PR scope: extract the duplicated request checks without changing the
`workflow_dispatch` or `workflow_call` interfaces.

## Current implementation status

This follow-up is implemented on branch `chore/bootstrap-validation-actions`.

- [x] Added `.github/actions/validate-bootstrap-owner/action.yml`
- [x] Added `.github/actions/audit-bootstrap-request/action.yml`
- [x] Updated `create-repository.yml` to call both shared actions
- [x] Updated `terraform-create-repository.yml` to call both shared actions
- [x] Preserved allowlist validation before token resolution
- [x] Ran `LINT_MODE=check make lint`
- [x] Ran manual E2E PAT tests for both `create-repository.yml` and
      `terraform-create-repository.yml`

This follow-up is implemented and validated. It can be considered ready to merge
once the branch is pushed and the required checks have passed.

## Background

During PR #26 review, Copilot identified that the following validation steps are
duplicated verbatim in both bootstrap entrypoints:

- **`Validate target owner against allowlist`** — allowlist check with
  normalization
- **`Audit bootstrap request`** — step-summary audit log
- **`Validate owner type vs auth mode`** — guards App auth against personal user
  accounts

Both `.github/workflows/create-repository.yml` and
`.github/workflows/terraform-create-repository.yml` contain identical copies of
this logic. Any future change (e.g. adding a new guardrail, changing audit fields)
must be applied in two places, creating drift risk.

## Proposed solution

Extract the duplicated logic into two small composite actions:

```text
.github/actions/validate-bootstrap-owner/
└── action.yml

.github/actions/audit-bootstrap-request/
└── action.yml
```

### `validate-bootstrap-owner`

Runs before token resolution, matching the current workflow order.

**Inputs:**

| Name                  | Description                             |
| --------------------- | --------------------------------------- |
| `owner`               | Target repo owner from `set-owner`      |
| `allowed_repo_owners` | Comma-separated allowlist, may be empty |

**Steps inside the action:**

1. Normalize `allowed_repo_owners` by lowercasing and removing whitespace.
2. Treat an empty normalized allowlist as no restriction.
3. Lowercase `owner` and require exact comma-delimited membership when the
   allowlist is configured.

### `audit-bootstrap-request`

Runs after `resolve-gh-token`, because it needs the resolved auth mode and token
for the owner type check.

**Inputs:**

| Name        | Description                         |
| ----------- | ----------------------------------- |
| `owner`     | Target owner from `set-owner`       |
| `repo_name` | Target repository name              |
| `auth_mode` | `app` or `pat` from `resolve-token` |
| `gh_token`  | Token for `gh api /users/{owner}`   |

**Steps inside the action:**

1. Audit log to `$GITHUB_STEP_SUMMARY`
2. Check owner type via `gh api /users/{owner}` — fail if `auth_mode=app` and `type=User`

**Callers replace the duplicated blocks with:**

```yaml
- name: Validate target owner
  uses: ./.github/actions/validate-bootstrap-owner
  with:
    owner: ${{ steps.set-owner.outputs.owner }}
    allowed_repo_owners: ${{ inputs.allowed_repo_owners }}
```

```yaml
- name: Audit bootstrap request
  uses: ./.github/actions/audit-bootstrap-request
  with:
    owner: ${{ steps.set-owner.outputs.owner }}
    repo_name: ${{ inputs.repo_name }}
    auth_mode: ${{ steps.resolve-token.outputs.auth_mode }}
    gh_token: ${{ steps.resolve-token.outputs.token }}
```

## Acceptance criteria

- [x] Both `create-repository.yml` and `terraform-create-repository.yml` call the
      shared actions instead of duplicating the bash
- [x] E2E PAT test still passes after extraction
- [x] Allowlist validation still runs before token resolution
- [x] All existing guards (allowlist, App-vs-User, audit log) behave identically
      by code inspection and local workflow linting
- [x] `make lint` passes

## Notes

- The composite actions live in the bootstrap repo's `.github/actions/` — they are
  always available after the `Checkout bootstrap repository` step.
- The two workflows differ in tool setup (Terraform vs raw shell) but the pre-flight
  validation is pure bash and has no tool dependencies.
- This is **not** a breaking change for callers — the `workflow_call` interface is
  unchanged.
- This extraction can be the first PR before the larger normalization refactor,
  because it removes exact duplication without introducing the new Go normalizer.
