# Maintenance automation: installation, security boundaries, and operations

This is the operator runbook for the automated, verified maintenance PR system
(parent issue #112). It covers installing the reusable GitHub Apps in another
owner, the credentials each one needs, the trust boundaries between them, and
how to recover when an automated PR stops moving.

Design references:

- [`github-app-trust-boundaries.md`](github-app-trust-boundaries.md) — the four
  App roles and why permissions are never shared.
- [`github-app-permission-matrix.md`](github-app-permission-matrix.md) —
  permission profile → endpoint mapping enforced by
  [`.github/actions/resolve-gh-token`](../.github/actions/resolve-gh-token/action.yml).
- [`github-app-manifests/`](github-app-manifests/) — reusable App Manifest
  payloads.

No private key, App user token, or client secret belongs in Git, in a
workflow-dispatch input, or in a generated repository. Client IDs and App slugs
are non-secret configuration.

## 1. Credential vocabulary

A GitHub App has four distinct identifiers. They are not interchangeable:

| Identifier                | Example variable                                                  | Secret?                                     | What it is                                                                                                                                   |
| ------------------------- | ----------------------------------------------------------------- | ------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| **App ID**                | not used by this repo                                             | No                                          | Numeric ID of the App registration. This repo authenticates by client ID instead; do not add App ID inputs.                                  |
| **Client ID**             | `BOOTSTRAP_*_APP_CLIENT_ID`                                       | No — repository or Environment **variable** | Identifies the App to `actions/create-github-app-token`. Pairs with the private key to mint an installation token.                           |
| **Installation ID**       | resolved at runtime                                               | No                                          | Identifies one installation of the App in one account. Never stored; `create-github-app-token` resolves it from `owner` + `repositories`.    |
| **Private key (PEM)**     | `BOOTSTRAP_*_APP_PRIVATE_KEY`                                     | Yes — repository or Environment **secret**  | GitHub-generated signing key. Mints installation tokens. Rotate on any suspected exposure.                                                   |
| **App slug**              | `BOOTSTRAP_*_APP_SLUG`, `BOOTSTRAP_MAINTENANCE_REVIEWER_APP_SLUG` | No — variable                               | URL name of the App. Used to assert the resolved token belongs to the expected App and to recognise `"<slug>[bot]"` as the commit/PR author. |
| **App user access token** | `BOOTSTRAP_PROVISIONER_APP_USER_TOKEN`                            | Yes — secret (`ghu_` prefix)                | Personal-account creation only. Tied to one user; identity is checked against the target owner. Never accepted as a workflow input.          |
| **Client secret**         | none stored                                                       | Yes (transient)                             | Used once during the manifest→user-token exchange for personal creation, then discarded.                                                     |

## 2. The four Apps and their Environments

Each role is a separate App with a separate private key. A single GitHub
Environment cannot hold two different values under the same variable or secret
name, so each role that needs the stable names below gets its own protected
Environment.

| App role                             | Manifest                                                                                              | Environment                                                                   | Credential names                                                                                                                                                                               | Permission profiles                                                             |
| ------------------------------------ | ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| **Repository Bootstrap Provisioner** | [`repository-bootstrap-provisioner.json`](github-app-manifests/repository-bootstrap-provisioner.json) | caller's launcher repo secret, or a provisioning Environment                  | `BOOTSTRAP_PROVISIONER_APP_CLIENT_ID` (var), `BOOTSTRAP_PROVISIONER_APP_PRIVATE_KEY` (secret), `BOOTSTRAP_PROVISIONER_APP_USER_TOKEN` (secret, personal only)                                  | `repository-creation`, `repository-setup`, `repository-cleanup`                 |
| **Repository Maintenance Writer**    | [`repository-maintenance-writer.json`](github-app-manifests/repository-maintenance-writer.json)       | `production-maintenance`                                                      | `BOOTSTRAP_MAINTENANCE_WRITER_APP_CLIENT_ID` (var), `BOOTSTRAP_MAINTENANCE_WRITER_APP_SLUG` (var), `BOOTSTRAP_MAINTENANCE_WRITER_APP_PRIVATE_KEY` (secret)                                     | `weekly-tooling`, `release-please`, `maintenance-labeling`, `maintenance-merge` |
| **Repository Maintenance Reviewer**  | [`repository-maintenance-reviewer.json`](github-app-manifests/repository-maintenance-reviewer.json)   | `production-maintenance`                                                      | `BOOTSTRAP_REVIEWER_APP_CLIENT_ID` (var), `BOOTSTRAP_MAINTENANCE_REVIEWER_APP_SLUG` (var), `BOOTSTRAP_REVIEWER_APP_PRIVATE_KEY` (secret)                                                       | `workflow-approval`, `maintenance-review`                                       |
| **Bootstrap E2E Admin**              | [`bootstrap-e2e-admin.json`](github-app-manifests/bootstrap-e2e-admin.json)                           | `e2e-cleanup` (scheduled deletion); test-generated E2E reads it at repo scope | `BOOTSTRAP_E2E_APP_CLIENT_ID` (var), `BOOTSTRAP_E2E_APP_OWNER` (var), `BOOTSTRAP_E2E_APP_PRIVATE_KEY` (secret), `BOOTSTRAP_E2E_ALLOWED_OWNERS` (var), `BOOTSTRAP_E2E_CENTRAL_REPOSITORY` (var) | `e2e-lifecycle`                                                                 |

Rules that must hold in any owner:

- **The E2E Admin is test-only.** Its `administration: write` includes
  repository **deletion**. Install it **only** in a disposable E2E owner listed
  in `BOOTSTRAP_E2E_ALLOWED_OWNERS`, never alongside production repositories.
  Cleanup refuses to run if the owner is not on the allowlist, and only ever
  deletes archived repos whose name matches
  `bootstrap-e2e-<run>-<attempt>-<provider>-<delivery>-<workflow>` and that
  carry the `bootstrap-e2e` topic.
- **Writer and Reviewer keys are distinct secrets** even when both Apps are
  installed on the same repository. The Reviewer never creates commits; the
  Writer never approves its own PRs.
- **No App is a ruleset bypass actor.** Rulesets stay authoritative for
  signatures, required reviews, required checks, linear history, and squash
  merge. Automation satisfies the rules; it does not skip them.
- Credential **names are stable**; the Environment (and its protection rules /
  required reviewers) decides which deployment may use them.

## 3. Installing the reusable Apps in another owner

For each role you need:

1. **Register the App from the manifest.** Do not craft permissions by hand:

   ```bash
   credential_dir="$HOME/.local/state/github-bootstrap/<role>"
   scripts/github-setup/github-app-manifest.sh start <role> "$credential_dir"
   # Open the printed URL, approve, let the local callback capture the one-time code.
   scripts/github-setup/github-app-manifest.sh convert-file \
     "$credential_dir/app-manifest-code" "$credential_dir"
   ```

   `<role>` is one of `repository-bootstrap-provisioner`,
   `repository-maintenance-writer`, `repository-maintenance-reviewer`,
   `bootstrap-e2e-admin`. Conversion writes the client ID, client secret, and
   private key under a `0700` directory with `0600` files, outside the checkout.

2. **Install the App** on the target owner and **select only the repositories**
   that role operates on. The E2E Admin goes on the disposable E2E owner only.

3. **Store the credentials** in the Environment that owns the role (section 2).
   Use `gh variable set` for client IDs / slugs / owners and `gh secret set` for
   private keys. For personal-account provisioning, also run the App
   user-token flow and `scripts/github-setup/install-app-secrets.sh` (see the
   root [`README.md`](../README.md) "Personal account" section).

4. **Configure the Environment protection rules.** `production-maintenance`
   should require the reviewers appropriate for merge-capable automation.

5. **Set repository/Environment variables the workflows read:**
   `BOOTSTRAP_COPILOT_REVIEWER_LOGIN` (the Copilot reviewer bot login, e.g.
   `copilot-pull-request-reviewer[bot]`), plus the E2E `*_ALLOWED_OWNERS` and
   `*_CENTRAL_REPOSITORY` values if you run the E2E lifecycle.

6. **Confirm the ruleset** (`.github/config/ruleset-default.json`) is applied to
   `main` with `Maintenance safety` among the required checks and an empty
   `bypass_actors`.

## 4. The maintenance PR lifecycle

```text
bot opens PR ─▶ Classify ─▶ labels: automation: maintenance + automation: validating
                                     (+ dependencies | + automation: breaking | + automation: blocked)
                    │
                    ├─▶ Approve Eligible Automation Workflows  (Reviewer App, workflow-approval)
                    │        approves the action_required runs after identity + freshness checks
                    │
                    ├─▶ required checks run at the PR head: Quality, Commit policy,
                    │        Test Quality Providers, CodeQL Security Scan
                    │
                    ├─▶ if automation: breaking ─▶ Dispatch Maintenance E2E (Reviewer App)
                    │        └─▶ Test Generated Repository E2E @ PR head SHA  (Provisioner + E2E Admin)
                    │
                    ├─▶ Copilot review gate: completed review, no unresolved threads
                    │        (bot-authored maintenance PRs may be exempt — see the validator)
                    │
                    ▼
              Maintenance safety  (required check; fail-closed on any missing/pending/stale/failed input)
                    │
                    ▼
              Merge Maintenance Pull Request
                    Reviewer App re-validates and APPROVES the exact head SHA,
                    Writer App enables squash auto-merge (or merges if already clean)
```

Labels:

| Label                     | Meaning                                                           |
| ------------------------- | ----------------------------------------------------------------- |
| `automation: maintenance` | Trusted automation PR; safety gate applies.                       |
| `automation: validating`  | Gates not yet all green.                                          |
| `automation: breaking`    | Major/breaking bump — a PR-head E2E run is required before merge. |
| `automation: blocked`     | Unknown risk or a failed gate — auto-merge is withheld.           |
| `dependencies`            | Dependabot-sourced update.                                        |

`Dispatch Maintenance E2E` (`.github/workflows/dispatch-maintenance-e2e.yml`)
is what makes a breaking PR hands-off: on `labeled`/`synchronize` it checks the
PR carries `automation: maintenance` + `automation: breaking`, resolves a
Reviewer App token (`workflow-approval`, the only profile with `actions: write`),
and dispatches `Test Generated Repository E2E` against the PR head branch with
`head_sha`, `client_id` (Provisioner), and `app_owner`. It skips if a run for
that exact head SHA already exists. `validate-maintenance-safety.sh` then
requires a successful E2E run whose `head_sha` equals the PR head.

## 5. Public E2E data and fork implications

- Generated E2E repositories are created **public** in the disposable E2E
  owner. Treat everything the E2E run produces as world-readable: run names,
  logs, generated files, and topics. Never feed real secrets or private
  templates into an E2E scenario.
- E2E repositories are marked with the `bootstrap-e2e` topic, **archived** as
  the first cleanup step, then deleted by the scheduled
  `Cleanup Archived E2E Repositories` workflow once archived and older than
  **90 days** (`validate-e2e-cleanup-candidate.sh`).
- `pull_request_target` workflows (Classify, Maintenance safety, Dispatch
  Maintenance E2E, Merge) check out **`main`**, never the PR head, and
  `dispatch-maintenance-e2e.yml` additionally requires
  `head.repo.full_name == github.repository`. A fork PR therefore cannot make
  the automation run fork code or dispatch a credentialed E2E run. Fork PRs are
  not eligible maintenance PRs and are ignored by the chain.
- The credentialed `Test Generated Repository E2E` and the personal-account
  E2E remain prerequisites before enabling production automation in a new
  owner.

## 6. Operator troubleshooting checklist

Work top-down; the chain is fail-closed, so a later stage never runs until the
earlier one is satisfied.

### Workflow runs stuck on "pending approval" (`action_required`)

- Confirm `Approve Eligible Automation Workflows` ran on the triggering run's
  completion. Check its logs for a resolved-App-identity mismatch (wrong
  `BOOTSTRAP_MAINTENANCE_REVIEWER_APP_SLUG` or client ID) or a resolve-token
  failure (missing/rotated `BOOTSTRAP_REVIEWER_APP_PRIVATE_KEY`, App not
  installed on the repo).
- The PR must be authored by `dependabot[bot]`, `release-please[bot]`,
  `github-actions[bot]` with `autorelease: pending`, or `"<writer-slug>[bot]"`,
  on a same-repo branch targeting `main`. Anything else is intentionally not
  approved.
- Re-approve manually only as a last resort: **Settings → Actions → pending
  deployments**, or re-run the approval workflow.

### Commit is not "verified" / signature rejected

- The Writer workflow creates the commit through the Git database API and
  rejects any result GitHub does not report as `verified` / `valid`
  (`verify-commit-verification.sh`). A failure here means the App's commit
  signing is off or the branch was pushed to out-of-band.
- Fix: let the Writer re-create the commit (re-run the weekly tooling /
  release-please job). Do not hand-push to the branch — a local unsigned commit
  will block the ruleset's signature requirement.

### Required checks missing, pending, failed, or stale

- `Maintenance safety` requires the **latest** `Quality`, `Commit policy`,
  `Test Quality Providers`, and `CodeQL Security Scan` runs to be `completed` /
  `success` **at the current PR head SHA**. A new push supersedes older runs;
  wait for the fresh set.
- "PR head is stale or mismatched" means the PR was updated after a gate ran.
  Push nothing further and let the chain re-converge on the new head.
- If a required workflow never started, check it is still `action_required` and
  see the approval item above.

### Breaking PR never merges — no E2E run

- The PR must have **both** `automation: maintenance` and `automation:
breaking`. Classification adds `breaking` only when the release major version
  increases or the tooling metadata marks a high/breaking/unknown risk.
- Check `Dispatch Maintenance E2E` fired on the `labeled` event. Common causes
  of no-op: `BOOTSTRAP_PROVISIONER_APP_CLIENT_ID` unset, Reviewer token resolve
  failed, or the head is a fork.
- Verify a `Test Generated Repository E2E` run exists whose `head_sha` matches
  the PR head. A run against `main` (wrong `--ref`) will not satisfy the gate.
- Manual fallback: run `Test Generated Repository E2E` via `workflow_dispatch`
  with `head_sha=<PR head>`, `client_id=<Provisioner client ID>`,
  `app_owner=<owner>`.

### Copilot review gate blocking

- `validate-copilot-review.sh` needs a completed review from
  `BOOTSTRAP_COPILOT_REVIEWER_LOGIN` at the current head and **no unresolved
  review threads** authored by that reviewer. Resolve or address the threads.
- If the reviewer login is misconfigured, the gate fails with "Copilot reviewer
  identity is not configured" — set the variable.
- More than 100 review threads exceeds the validation page and fails closed;
  trim the thread count.

### Auto-merge not enabled after all gates pass

- `Merge Maintenance Pull Request` runs on `Maintenance safety` completion. It
  re-validates from scratch, then the Reviewer App approves the exact head SHA
  and the Writer App enables squash auto-merge.
- "Maintenance safety validated `<validated-sha>` but the PR head is now
  `<current-sha>`" — the head moved; the next `Maintenance safety` run will
  re-trigger the merge.
- `enablePullRequestAutoMerge` needs `contents: write`, which only the Writer's
  `maintenance-merge` profile carries; a resolve failure there blocks the final
  step even though the approval succeeded.
- If `mergeable_state` is `clean`, the workflow merges outright instead of
  enabling auto-merge; a `blocked`/`behind` state means a rule is still
  unsatisfied — recheck the required checks and approvals.

### Stale or abandoned PR

- Close superseded weekly-tooling / Dependabot PRs; the next run opens a fresh
  one from `main`.
- Never bypass the ruleset to force-merge. If automation cannot satisfy a gate,
  fix the gate input or merge manually through the normal reviewed path.

## 7. Recovering from blocked automation

1. Identify the earliest unsatisfied stage from section 6.
2. Fix the **input** to that stage (credential, label, stale run, unresolved
   thread) — not the gate.
3. Re-trigger by pushing a new head via the owning bot, re-running the stage
   workflow, or (E2E only) a manual `workflow_dispatch` with the PR head SHA.
4. `repository_dispatch: maintenance-safety` with `{pr_number, head_sha}` can
   force a safety re-evaluation without a new commit.
5. If a credential was exposed, rotate the App private key in GitHub, update the
   Environment secret, and re-run.

Do not add an App to `bypass_actors`, share one key between roles, or move E2E
deletion credentials into a production Environment to work around a failure.
