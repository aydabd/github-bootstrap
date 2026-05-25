# Follow-up: Extract shared pre-flight validation into a composite action

## Background

During PR #26 review, Copilot identified that the following validation steps are
duplicated verbatim in both bootstrap entrypoints:

- **`Validate target owner against allowlist`** — allowlist check with normalization
- **`Audit bootstrap request`** — step-summary audit log
- **`Validate owner type vs auth mode`** — guards App auth against personal user accounts

Both `.github/workflows/create-repository.yml` and
`.github/workflows/terraform-create-repository.yml` contain identical copies of
this logic. Any future change (e.g. adding a new guardrail, changing audit fields)
must be applied in two places, creating drift risk.

## Proposed solution

Extract into a new composite action at `.github/actions/validate-bootstrap-request/`.

```text
.github/actions/validate-bootstrap-request/
└── action.yml
```

**Inputs:**

| Name                  | Description                                            |
| --------------------- | ------------------------------------------------------ |
| `owner`               | Target repo owner (from `set-owner` step)              |
| `allowed_repo_owners` | Comma-separated allowlist (may be empty)               |
| `auth_mode`           | `app` or `pat` (from `resolve-gh-token`)               |
| `gh_token`            | Resolved token for API calls (`gh api /users/{owner}`) |

**Steps inside the action:**

1. Validate allowlist (normalize → check empty → check membership)
2. Audit log to `$GITHUB_STEP_SUMMARY`
3. Check owner type via `gh api /users/{owner}` — fail if `auth_mode=app` and `type=User`

**Callers replace ~40 lines with:**

```yaml
- name: Validate bootstrap request
  uses: ./.github/actions/validate-bootstrap-request
  with:
    owner: ${{ steps.set-owner.outputs.owner }}
    allowed_repo_owners: ${{ inputs.allowed_repo_owners }}
    auth_mode: ${{ steps.resolve-token.outputs.auth_mode }}
    gh_token: ${{ steps.resolve-token.outputs.token }}
```

## Acceptance criteria

- [ ] Both `create-repository.yml` and `terraform-create-repository.yml` call the
      shared action instead of duplicating the bash
- [ ] E2E PAT test still passes after extraction
- [ ] All existing guards (allowlist, App-vs-User, audit log) behave identically
- [ ] `make lint` passes

## Notes

- The composite action lives in the bootstrap repo's `.github/actions/` — it is
  always available after the `Checkout bootstrap repository` step.
- The two workflows differ in tool setup (Terraform vs raw shell) but the pre-flight
  validation is pure bash and has no tool dependencies.
- This is **not** a breaking change for callers — the `workflow_call` interface is
  unchanged.
