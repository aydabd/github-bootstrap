# GitHub App trust boundaries

This repository uses separate GitHub Apps for separate trust boundaries. The
JSON files in [`github-app-manifests/`](github-app-manifests/) are reusable
starting payloads for GitHub's App Manifest flow. Before installation, the
consumer must review the target owner, selected repositories, and permissions.
GitHub's automatic `metadata: read` permission is declared explicitly in each
payload for auditability.

## App roles

| App                                  | Scope and authority                                                                                                                                                                                             | Credentials                                                                                                                | Explicitly excluded                                                                                                               |
| ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| **Bootstrap E2E Admin**              | Test-only administration of repositories created by the generated-repository E2E system, including creation and archive lifecycle operations. Install only in the disposable E2E owner.                         | E2E-only App private key, held in the E2E environment.                                                                     | Production repositories, production maintenance credentials, repository contents, pull requests, workflow approval, and deletion. |
| **Repository Bootstrap Provisioner** | Consumer-owned setup of an existing or newly created target repository: settings, generated contents, labels, and repository configuration. Install only on the consumer-selected repositories or organization. | Consumer-owned provisioner App private key, held by the consumer's protected workflow secret.                              | E2E administration, maintenance PR review/merge, workflow approval, and ruleset bypass.                                           |
| **Repository Maintenance Writer**    | Creates verified maintenance commits and opens or updates maintenance pull requests in explicitly selected repositories.                                                                                        | Production Writer App private key, held in the production maintenance environment.                                         | E2E administration, workflow approval, review, auto-merge, and ruleset bypass.                                                    |
| **Repository Maintenance Reviewer**  | Approves eligible workflow runs, completes the automation review/merge orchestration, and enables auto-merge after all policy gates pass. Install only on explicitly selected maintenance repositories.         | Production Reviewer App private key, held in the production maintenance environment and kept separate from the Writer key. | E2E administration, commit creation, arbitrary repository administration, and ruleset bypass.                                     |

The E2E Admin is never used by production maintenance workflows. The Writer
and Reviewer are separate Apps even when they are installed on the same target
repository. No App is a ruleset bypass actor: rulesets remain authoritative
for signatures, approvals, required checks, linear history, and merge method.

## Permission contract

The payloads intentionally have no webhook events and are private Apps. Their
default permissions are the complete requested contract:

| App                              | Permissions                                                                     |
| -------------------------------- | ------------------------------------------------------------------------------- |
| Bootstrap E2E Admin              | `organization_administration: write`, `administration: write`, `metadata: read` |
| Repository Bootstrap Provisioner | `administration: write`, `contents: write`, `issues: write`, `metadata: read`   |
| Repository Maintenance Writer    | `contents: write`, `pull_requests: write`, `metadata: read`                     |
| Repository Maintenance Reviewer  | `actions: write`, `pull_requests: write`, `metadata: read`                      |

Permissions are not shared between roles for convenience. GitHub's
`administration: write` permission includes repository deletion capability;
the E2E Admin and Provisioner need that permission for their documented
administration operations, but their workflows must never delete arbitrary or
production repositories. No manifest requests a separate deletion permission,
`workflows`, `members`, `security-events`, or unrelated-owner access. Later
workflow issues must use the narrowest role and repository selection that
satisfies their operation; they must not expand a manifest here to bypass a
ruleset or combine the E2E and production trust boundaries.

## Installation and secret handling

Organization consumers install the appropriate App on the organization and
select only the repositories needed by that role. Personal-account consumers
must use the supported App user-token flow for personal targets; an
installation token does not become a personal-user credential. The configured
owner and authenticated identity must match before any operation.

Store each App's GitHub-generated private key as a protected
`BOOTSTRAP_APP_PRIVATE_KEY` secret in the environment that owns that role.
For the weekly Writer workflow, use the protected `production-maintenance`
Environment and set `BOOTSTRAP_APP_CLIENT_ID` and
`BOOTSTRAP_MAINTENANCE_WRITER_APP_SLUG` as Environment variables alongside
the `BOOTSTRAP_APP_PRIVATE_KEY` Environment secret. These names remain stable;
the Environment identifies which deployment is authorized to use them.
The same Writer App may use the narrower `maintenance-labeling` profile for
the pull-request classifier; that profile grants only `issues: write` and
`pull_requests: read` to apply lifecycle labels to trusted Dependabot and
release-please PRs.
Do not commit keys, include them in workflow inputs, print them, or reuse an
E2E key in production. The production Reviewer key is a distinct secret from
the Writer key and the E2E key. Client IDs may be non-secret configuration, but
private keys and App user access tokens remain protected credentials.

E2E repositories and credentials are scoped to the E2E owner and the exact
system-generated names/markers. E2E lifecycle work must archive generated
public repositories before cleanup and must never delete arbitrary or
production repositories. Detailed archive and cleanup behavior belongs to
issues #118 and #119, not this manifest contract.
