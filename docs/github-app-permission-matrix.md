# GitHub App permission-to-endpoint matrix

The reusable four-role trust boundary and manifest payloads are documented in
[`github-app-trust-boundaries.md`](github-app-trust-boundaries.md). This
matrix retains the operation-level profiles used by the existing bootstrap
workflows; those profiles must remain within the corresponding App role.

Organization repository creation uses an installation token for the requested `app_owner` only.
Personal repository creation uses an explicitly supplied GitHub App user access token whose `/user`
identity is checked against the target owner. The resolver passes permissions explicitly so an
installation token does not inherit unused permissions from the App installation.

| Permission profile     | Explicit App permissions                                                                          | Used for                                                       |
| ---------------------- | ------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `repository-creation`  | `organization-administration: write`, `administration: write`, `contents: write`, `issues: write` | Create and configure a repository.                             |
| `repository-setup`     | `administration: write`, `contents: write`, `issues: write`                                       | Configure an existing repository.                              |
| `repository-cleanup`   | `administration: write`                                                                           | Delete a failed repository.                                    |
| `e2e-lifecycle`        | `administration: write`                                                                           | Archive generated E2E repositories in the isolated E2E owner.  |
| `weekly-tooling`       | `contents: write`, `issues: write`, `pull-requests: write`                                        | Commit tooling updates, labels, and manage the weekly PR.      |
| `maintenance-labeling` | `issues: write`, `pull-requests: read`                                                            | Classify trusted Dependabot and release-please PRs.            |
| `workflow-approval`    | `actions: write`, `pull-requests: read`                                                           | Approve eligible `action_required` workflow runs only.         |
| `maintenance-review`   | `pull-requests: write`                                                                            | Approve eligible maintenance PRs and enable squash auto-merge. |

| App permission                | Level | Endpoint or operation                                                      | Why it is required                                                                                     |
| ----------------------------- | ----- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `organization-administration` | write | `POST /orgs/{org}/repos`                                                   | Create the repository in the target organization.                                                      |
| `administration`              | write | `PATCH /repos/{owner}/{repo}`, environments, rulesets, repository deletion | Configure the repository; deletion capability is operationally restricted to the documented lifecycle. |
| `contents`                    | write | Git push and repository contents API                                       | Add generated bootstrap files.                                                                         |
| `issues`                      | write | Labels API                                                                 | Apply default repository labels.                                                                       |
| `pull-requests`               | write | Weekly tooling PR creation, updates, and auto-merge                        | Run the App-authenticated weekly tooling automation.                                                   |
| `actions`                     | write | `POST /repos/{owner}/{repo}/actions/runs/{run_id}/approve`                 | Approve an eligible workflow run after all identity and freshness checks pass.                         |

`metadata: read` is automatically available for repository access. Members, security-events,
and unrelated-owner permissions are not granted by this resolver. The `actions: write`
permission is granted only by the `workflow-approval` profile. Pull-request
write permission is granted by the `weekly-tooling` and `maintenance-review` profiles. Issues write permission is
limited to the weekly profile's and `maintenance-labeling` profile's idempotent pull-request label operations and
the existing repository creation/setup profiles' repository label configuration.

The `e2e-lifecycle` profile intentionally omits a repository list because the generated
repository does not exist when its token is resolved. Use it only with the Bootstrap E2E Admin
App installed exclusively in the disposable E2E owner; the workflow still validates the exact
owner, generated name, and marker topic before archiving.

The weekly maintenance workflow requires the non-secret
`BOOTSTRAP_MAINTENANCE_WRITER_APP_SLUG` variable. It creates the commit through
the Git database API using the authenticated Maintenance Writer App token and
includes a Signed-off-by trailer in the commit message; it does not create a
local commit, persist a token in Git configuration, or accept a custom signing
key. The workflow rejects any resulting commit that GitHub does not report as
`verified` with reason `valid`.

Configure these values in the protected `production-maintenance` GitHub
Environment: `BOOTSTRAP_MAINTENANCE_WRITER_APP_CLIENT_ID` and
`BOOTSTRAP_MAINTENANCE_WRITER_APP_SLUG` as variables, and
`BOOTSTRAP_MAINTENANCE_WRITER_APP_PRIVATE_KEY` as a secret. The credential names are stable
across deployment Environments; Environment scope and protection rules define
which deployment may use them.

The workflow approval workflow uses separate Reviewer App credentials in the
same protected Environment: `BOOTSTRAP_REVIEWER_APP_CLIENT_ID` and
`BOOTSTRAP_MAINTENANCE_REVIEWER_APP_SLUG` as variables, and
`BOOTSTRAP_REVIEWER_APP_PRIVATE_KEY` as a secret. The Reviewer App has no
ruleset bypass authority.

Creation installation tokens intentionally omit a repository list because the target repository
does not exist yet. Existing-repository setup, cleanup, and weekly tooling callers pass the
repository name to scope the installation token to that repository. Personal creation uses
`POST /user/repos`, which is tied to the authenticated user; user access tokens are never accepted
as workflow-dispatch inputs or used for organization creation.

| Creation target | Authentication         | Endpoint                 | Why                                                                                      |
| --------------- | ---------------------- | ------------------------ | ---------------------------------------------------------------------------------------- |
| Organization    | App installation token | `POST /orgs/{org}/repos` | Organization-scoped repository creation.                                                 |
| Personal user   | App user access token  | `POST /user/repos`       | The API requires a token for the authenticated user; `/user` identity is verified first. |
