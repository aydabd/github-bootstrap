# GitHub App permission-to-endpoint matrix

Organization repository creation uses an installation token for the requested `app_owner` only.
Personal repository creation uses an explicitly supplied GitHub App user access token whose `/user`
identity is checked against the target owner. The resolver passes permissions explicitly so an
installation token does not inherit unused permissions from the App installation.

| Permission profile    | Explicit App permissions                                                                          | Used for                                         |
| --------------------- | ------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| `repository-creation` | `organization-administration: write`, `administration: write`, `contents: write`, `issues: write` | Create and configure a repository.               |
| `repository-setup`    | `administration: write`, `contents: write`, `issues: write`                                       | Configure an existing repository.                |
| `repository-cleanup`  | `administration: write`                                                                           | Delete a failed repository.                      |
| `weekly-tooling`      | `contents: write`, `pull-requests: write`                                                         | Commit tooling updates and manage the weekly PR. |

| App permission                | Level | Endpoint or operation                                                      | Why it is required                                     |
| ----------------------------- | ----- | -------------------------------------------------------------------------- | ------------------------------------------------------ |
| `organization-administration` | write | `POST /orgs/{org}/repos`                                                   | Create the repository in the target organization.      |
| `administration`              | write | `PATCH /repos/{owner}/{repo}`, environments, rulesets, repository deletion | Configure the repository and clean up failed creation. |
| `contents`                    | write | Git push and repository contents API                                       | Add generated bootstrap files.                         |
| `issues`                      | write | Labels API                                                                 | Apply default repository labels.                       |
| `pull-requests`               | write | Weekly tooling PR creation, updates, and auto-merge                        | Run the App-authenticated weekly tooling automation.   |

`metadata: read` is automatically available for repository access. Members, actions,
security-events, and unrelated-owner permissions are not granted by this resolver. Pull-request
write permission is granted only by the `weekly-tooling` profile.

Creation installation tokens intentionally omit a repository list because the target repository
does not exist yet. Existing-repository setup, cleanup, and weekly tooling callers pass the
repository name to scope the installation token to that repository. Personal creation uses
`POST /user/repos`, which is tied to the authenticated user; user access tokens are never accepted
as workflow-dispatch inputs or used for organization creation.

| Creation target | Authentication         | Endpoint                 | Why                                                                                      |
| --------------- | ---------------------- | ------------------------ | ---------------------------------------------------------------------------------------- |
| Organization    | App installation token | `POST /orgs/{org}/repos` | Organization-scoped repository creation.                                                 |
| Personal user   | App user access token  | `POST /user/repos`       | The API requires a token for the authenticated user; `/user` identity is verified first. |
