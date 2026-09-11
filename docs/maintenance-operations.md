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

Never store secrets in generated repository contents, workflow inputs, or logs;
the provisioning action may store them only as encrypted Environment secrets.
Client IDs and App slugs are non-secret configuration.

## Operator boundary for live verification

This document contains commands and credential names only. Live verification is
operator-controlled: an operator must manually create the Apps, approve the
GitHub App installation, enter the credentials into protected Environments, and
approve any protected Environment deployment. This runbook never asks an
operator to paste a secret into chat, an issue, a workflow input, or a log.

The canonical profile-to-name mapping is
[`app-credential-profiles.json`](../scripts/github-setup/app-credential-profiles.json).
Use the profile names exactly as written there:

| Profile                    | Environment               | Non-secret variables                                                                              | Secrets                                                                                                                                                                |
| -------------------------- | ------------------------- | ------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `e2e-maintenance-writer`   | `e2e-maintenance`         | `BOOTSTRAP_E2E_MAINTENANCE_WRITER_APP_CLIENT_ID`, `BOOTSTRAP_E2E_MAINTENANCE_WRITER_APP_SLUG`     | `BOOTSTRAP_E2E_MAINTENANCE_WRITER_APP_PRIVATE_KEY`                                                                                                                     |
| `e2e-maintenance-reviewer` | `e2e-maintenance`         | `BOOTSTRAP_E2E_MAINTENANCE_REVIEWER_APP_CLIENT_ID`, `BOOTSTRAP_E2E_MAINTENANCE_REVIEWER_APP_SLUG` | `BOOTSTRAP_E2E_MAINTENANCE_REVIEWER_APP_PRIVATE_KEY`                                                                                                                   |
| `e2e-maintenance-fixture`  | `e2e-maintenance`         | `BOOTSTRAP_E2E_MAINTENANCE_FIXTURE_APP_CLIENT_ID`, `BOOTSTRAP_E2E_MAINTENANCE_FIXTURE_APP_SLUG`   | `BOOTSTRAP_E2E_MAINTENANCE_FIXTURE_APP_PRIVATE_KEY`, `BOOTSTRAP_E2E_MAINTENANCE_FIXTURE_APP_CLIENT_SECRET`, `BOOTSTRAP_E2E_MAINTENANCE_FIXTURE_APP_USER_REFRESH_TOKEN` |
| `e2e-provisioner`          | `e2e-testing`             | `BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_ID`                                                         | `BOOTSTRAP_E2E_PROVISIONER_APP_PRIVATE_KEY`, `BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_SECRET`, `BOOTSTRAP_E2E_PROVISIONER_APP_USER_REFRESH_TOKEN`                         |
| `production-provisioner`   | `production-provisioning` | `BOOTSTRAP_PRODUCTION_PROVISIONER_APP_CLIENT_ID`                                                  | `BOOTSTRAP_PRODUCTION_PROVISIONER_APP_PRIVATE_KEY`, `BOOTSTRAP_PRODUCTION_PROVISIONER_APP_CLIENT_SECRET`, `BOOTSTRAP_PRODUCTION_PROVISIONER_APP_USER_REFRESH_TOKEN`    |

The E2E Writer and Reviewer Apps, and the E2E provisioner/lifecycle Apps, must
be installed only in the disposable owner configured in
`BOOTSTRAP_E2E_ALLOWED_OWNERS`. The `app_owner` dispatch value must be that same
allowlisted owner. Never install an E2E App in an owner containing production
repositories.

## E2E maintenance setup and operations

The focused generated-repository scenario is enabled with
`maintenance_lifecycle=true` on `test-generated-repository-e2e.yml`. It creates
one public repository with `quality,maintenance`, opens a deterministic
human-controlled maintenance fixture PR, and observes classification, quality,
Copilot review validation, Reviewer approval, Writer auto-merge, release PR
creation and merge, tag/release push, and final provenance.

The fixture PR is created with a short-lived GitHub App user access token for
the disposable E2E owner. This is intentional: Copilot does not review PRs
opened by GitHub Apps or bots. The workflow exchanges the protected,
rotating `ghr_...` refresh token at runtime and never stores the resulting
`ghu_...` access token. The fixture App credentials remain source-only; the
Writer and Reviewer App credentials are still the identities used for
maintenance classification, approval, auto-merge, and release operations.

The fixture account's exact GitHub login is `e2e-maintenance-user`. Generated
maintenance workflows bind `MAINTENANCE_IDENTITY_MODE=e2e-disposable`,
`MAINTENANCE_FIXTURE_LOGIN=e2e-maintenance-user`, and
`MAINTENANCE_COPILOT_REVIEWER_LOGIN=copilot-pull-request-reviewer[bot]`.
Production workflows leave this mode unset and therefore accept only their
configured automation bot identities; the fixture login is never a production
fallback.

Configure the E2E Writer and Reviewer Apps from the checked-in
[`repository-maintenance-writer-e2e.json`](github-app-manifests/repository-maintenance-writer-e2e.json)
and
[`repository-maintenance-reviewer-e2e.json`](github-app-manifests/repository-maintenance-reviewer-e2e.json)
manifests. The manifest helper's supported E2E role arguments are
`repository-maintenance-writer-e2e` and `repository-maintenance-reviewer-e2e`;
the production role arguments remain separate. Configure the fixture App from
[`maintenance-fixture-e2e.json`](github-app-manifests/maintenance-fixture-e2e.json)
and authorize it as `e2e-maintenance-user`. Store its client ID and slug as
variables, and its private key, client secret, and refresh token as secrets in
the source `OWNER/github-bootstrap` repository's `e2e-maintenance` Environment.
Store the Writer and Reviewer client IDs and slugs as variables and their
private keys as secrets in the source
`OWNER/github-bootstrap` repository's `e2e-maintenance` Environment. The creation
workflow provisions those credentials into each generated repository's matching
Environment. The E2E workflow resolves installation tokens at runtime; it never
accepts a token or private key as an input.
It must never use production-maintenance credentials.

The scenario polls each transition with bounded limits and prints only safe
diagnostics (stage, state, and workflow or pull-request URL). It marks the
repository with the `bootstrap-e2e` topic and archives the exact generated name
on success, failure, or cancellation. The scheduled cleanup workflow removes
archived E2E repositories according to the configured retention period.

To troubleshoot a run, inspect the stage URL in its summary, then check the
generated PR's labels and required checks. Do not copy private keys or token
values into issue comments, workflow inputs, or logs. Re-run the focused
scenario after correcting the E2E Environment or App installation; production
repositories and the `production-maintenance` Environment are out of scope.

## 1. Credential vocabulary

A GitHub App has four distinct identifiers. They are not interchangeable:

| Identifier            | Example variable                                                                                                | Secret?                                     | What it is                                                                                                                                            |
| --------------------- | --------------------------------------------------------------------------------------------------------------- | ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| **App ID**            | not used by this repo                                                                                           | No                                          | Numeric ID of the App registration. This repo authenticates by client ID instead; do not add App ID inputs.                                           |
| **Client ID**         | `BOOTSTRAP_*_APP_CLIENT_ID`                                                                                     | No — repository or Environment **variable** | Identifies the App to `actions/create-github-app-token`. Pairs with the private key to mint an installation token.                                    |
| **Installation ID**   | resolved at runtime                                                                                             | No                                          | Identifies one installation of the App in one account. Never stored; `create-github-app-token` resolves it from `owner` + `repositories`.             |
| **Private key (PEM)** | `BOOTSTRAP_*_APP_PRIVATE_KEY`                                                                                   | Yes — repository or Environment **secret**  | GitHub-generated signing key. Mints installation tokens. Rotate on any suspected exposure.                                                            |
| **App slug**          | `BOOTSTRAP_*_APP_SLUG`, `BOOTSTRAP_MAINTENANCE_REVIEWER_APP_SLUG`                                               | No — variable                               | URL name of the App. Used to assert the resolved token belongs to the expected App and to recognise `"<slug>[bot]"` as the commit/PR author.          |
| **App refresh token** | `BOOTSTRAP_PRODUCTION_PROVISIONER_APP_USER_REFRESH_TOKEN` or `BOOTSTRAP_E2E_PROVISIONER_APP_USER_REFRESH_TOKEN` | Yes — secret (`ghr_` prefix)                | Personal-account creation only. Exchanged at runtime and rotated back into the same profile's Environment secret. Never accepted as a workflow input. |
| **Client secret**     | `BOOTSTRAP_PRODUCTION_PROVISIONER_APP_CLIENT_SECRET` or `BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_SECRET`           | Yes — secret                                | Used with the profile's refresh token to mint a short-lived user access token. Never printed or passed to a generated repository.                     |

## 2. The four Apps and their Environments

Each role is a separate App with a separate private key. A single GitHub
Environment cannot hold two different values under the same variable or secret
name, so each role that needs the stable names below gets its own protected
Environment.

| App role                                        | Manifest                                                                                              | Environment                                                                   | Credential names                                                                                                                                                                                                                                                      | Permission profiles                                                                       |
| ----------------------------------------------- | ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| **Production Repository Bootstrap Provisioner** | [`repository-bootstrap-provisioner.json`](github-app-manifests/repository-bootstrap-provisioner.json) | `production-provisioning`                                                     | `BOOTSTRAP_PRODUCTION_PROVISIONER_APP_CLIENT_ID` (var), `BOOTSTRAP_PRODUCTION_PROVISIONER_APP_PRIVATE_KEY` (secret), `BOOTSTRAP_PRODUCTION_PROVISIONER_APP_CLIENT_SECRET` (secret), `BOOTSTRAP_PRODUCTION_PROVISIONER_APP_USER_REFRESH_TOKEN` (secret, personal only) | `production-provisioner`: `repository-creation`, `repository-setup`, `repository-cleanup` |
| **E2E Repository Bootstrap Provisioner**        | [`repository-bootstrap-provisioner.json`](github-app-manifests/repository-bootstrap-provisioner.json) | `e2e-testing`                                                                 | `BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_ID` (var), `BOOTSTRAP_E2E_PROVISIONER_APP_PRIVATE_KEY` (secret), `BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_SECRET` (secret), `BOOTSTRAP_E2E_PROVISIONER_APP_USER_REFRESH_TOKEN` (secret, personal only)                             | `e2e-provisioner`: repository creation, setup, cleanup, and E2E dispatch                  |
| **Repository Maintenance Writer**               | [`repository-maintenance-writer.json`](github-app-manifests/repository-maintenance-writer.json)       | `production-maintenance`                                                      | `BOOTSTRAP_MAINTENANCE_WRITER_APP_CLIENT_ID` (var), `BOOTSTRAP_MAINTENANCE_WRITER_APP_SLUG` (var), `BOOTSTRAP_MAINTENANCE_WRITER_APP_PRIVATE_KEY` (secret)                                                                                                            | `weekly-tooling`, `release-please`, `maintenance-labeling`, `maintenance-merge`           |
| **Repository Maintenance Reviewer**             | [`repository-maintenance-reviewer.json`](github-app-manifests/repository-maintenance-reviewer.json)   | `production-maintenance`                                                      | `BOOTSTRAP_MAINTENANCE_REVIEWER_APP_CLIENT_ID` (var), `BOOTSTRAP_MAINTENANCE_REVIEWER_APP_SLUG` (var), `BOOTSTRAP_MAINTENANCE_REVIEWER_APP_PRIVATE_KEY` (secret)                                                                                                      | `workflow-approval`, `maintenance-review`                                                 |
| **Bootstrap E2E Admin**                         | [`bootstrap-e2e-admin.json`](github-app-manifests/bootstrap-e2e-admin.json)                           | `e2e-cleanup` (scheduled deletion); test-generated E2E reads it at repo scope | `BOOTSTRAP_E2E_APP_CLIENT_ID` (var), `BOOTSTRAP_E2E_APP_OWNER` (var), `BOOTSTRAP_E2E_APP_PRIVATE_KEY` (secret), `BOOTSTRAP_E2E_ALLOWED_OWNERS` (var), `BOOTSTRAP_E2E_CENTRAL_REPOSITORY` (var)                                                                        | `e2e-lifecycle`                                                                           |

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
   `repository-maintenance-writer-e2e`, `repository-maintenance-reviewer-e2e`,
   `maintenance-fixture-e2e`,
   `bootstrap-e2e-admin`. Conversion writes the client ID, client secret, and
   private key under a `0700` directory with `0600` files, outside the checkout.

2. **Install the App** on the target owner and **select only the repositories**
   that role operates on. The E2E Admin goes on the disposable E2E owner only.

3. **Store the credentials** in the Environment that owns the role (section 2). The two
   provisioner Apps are separate registrations and credential sets; never share a private key,
   client secret, client ID, or refresh token. The lifecycle App is separate from both provisioners.
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

### 3.1 Exact E2E maintenance App setup

Run these non-secret commands from the repository checkout. They use the
checked-in manifests and keep conversion output outside the checkout:

```bash
credential_dir="$HOME/.local/state/github-bootstrap/e2e-maintenance-writer"
scripts/github-setup/github-app-manifest.sh start repository-maintenance-writer-e2e "$credential_dir"
# Open the printed local URL, approve the App, and let the callback finish.
scripts/github-setup/github-app-manifest.sh convert-file \
  "$credential_dir/app-manifest-code" "$credential_dir"

credential_dir="$HOME/.local/state/github-bootstrap/e2e-maintenance-reviewer"
scripts/github-setup/github-app-manifest.sh start repository-maintenance-reviewer-e2e "$credential_dir"
# Open the printed local URL, approve the App, and let the callback finish.
scripts/github-setup/github-app-manifest.sh convert-file \
  "$credential_dir/app-manifest-code" "$credential_dir"
```

In GitHub, install each maintenance App account-wide in the owner it serves:
install the production Writer and Reviewer in the production owner with
**All repositories** selected, and install the E2E Writer and Reviewer in the
disposable E2E owner with **All repositories** selected. Account-wide
installation is required because repositories are created after the
installation preflight; repository selection would make newly generated
repositories invisible to the App. Never install an E2E App in a production
owner, and never install a production App in the disposable E2E owner.
The single command below installs both maintenance Apps and the fixture App
into the source bootstrap repository's `OWNER/github-bootstrap`
`e2e-maintenance` Environment. It must not be run against an already-generated
repository. The creation workflow copies/provisions only the Writer and
Reviewer App credentials into each generated repository's matching
`e2e-maintenance` Environment; the fixture App credentials remain source-only.
Conversion writes `app-client-id`, `app-private-key.pem`, and
`app-client-secret` with protected local permissions and does not print their
contents. The maintenance installer needs the client ID, App slug, and private
key files:

```bash
 # GH_TOKEN must already be set to an authorized operator token; do not print it.
repo="OWNER/github-bootstrap"

writer_dir="$HOME/.local/state/github-bootstrap/e2e-maintenance-writer"
reviewer_dir="$HOME/.local/state/github-bootstrap/e2e-maintenance-reviewer"
fixture_dir="$HOME/.local/state/github-bootstrap/e2e-maintenance-fixture"
```

The manifest conversion does not produce an App slug file. After an operator
reads the slug from the App page, store it in a protected local file without
printing it, for example:

```bash
umask 077
read -r -p "E2E Writer App slug (non-secret): " writer_slug
printf '%s\n' "$writer_slug" > "$writer_dir/app-slug"
unset writer_slug
read -r -p "E2E Reviewer App slug (non-secret): " reviewer_slug
printf '%s\n' "$reviewer_slug" > "$reviewer_dir/app-slug"
unset reviewer_slug
```

After creating and authorizing the fixture App, place its client secret and
refresh token in protected files. The refresh token must have the `ghr_`
prefix; do not create a PAT or a `ghu_` access-token file.

```bash
test -d "$fixture_dir"
chmod 700 "$fixture_dir"
umask 077
IFS= read -r -s -p 'E2E fixture App client secret: ' fixture_client_secret
printf '\n'
printf '%s' "$fixture_client_secret" > "$fixture_dir/app-client-secret"
unset fixture_client_secret
IFS= read -r -s -p 'E2E fixture App refresh token: ' fixture_refresh_token
printf '\n'
case "$fixture_refresh_token" in ghr_*) ;; *) echo 'refresh token must start with ghr_' >&2; exit 1 ;; esac
printf '%s' "$fixture_refresh_token" > "$fixture_dir/app-user-refresh-token"
unset fixture_refresh_token
chmod 600 "$fixture_dir/app-client-secret" "$fixture_dir/app-user-refresh-token"
```

Now invoke the installer. It validates the protected local files and source
repository scope, then writes the fixed `e2e-maintenance` variables and secrets
idempotently. App-installation access is validated by the runtime,
App-authenticated provisioning action; a missing installation prints an
App-specific remediation URL without printing credential values.

```bash
scripts/github-setup/install-e2e-maintenance-credentials.sh \
  "$repo" "$writer_dir" "$reviewer_dir" "$fixture_dir"
```

### Manual preflight sequence

Verify both App installations before dispatching an E2E creation run: install
both E2E maintenance Apps account-wide, configure the
source `e2e-maintenance` Environment, create the protected fixture App files,
and run the installer above. For an already generated repository, an
installation token can confirm account-wide visibility without exposing a
credential value:

```bash
GH_TOKEN="$MAINTENANCE_WRITER_INSTALLATION_TOKEN" \
  gh api --paginate --slurp /installation/repositories | \
  jq --arg repo "$repo" '[.[][] | select(.full_name == $repo)] | length == 1'
GH_TOKEN="$MAINTENANCE_REVIEWER_INSTALLATION_TOKEN" \
  gh api --paginate --slurp /installation/repositories | \
  jq --arg repo "$repo" '[.[][] | select(.full_name == $repo)] | length == 1'
```

Each response must include the target repository before continuing. Then run
the focused workflow dispatch in section 8 and confirm that the generated
repository has its matching `e2e-maintenance` Environment. For production
creation, use the same sequence with the production Writer and Reviewer
installation tokens and confirm the matching `production-maintenance`
Environment. A missing installation must stop the create workflow; do not
retry with credentials from the other owner or Environment.

If an operator must re-enter a private key or client secret manually, use the
multiline no-echo reader below. `read -r -s` alone reads only one line, so it is
not suitable for PEM values. This reader disables terminal echo, reads until EOF
or the explicit terminator, restores echo on normal completion, errors, or
cancellation, and sends the value to `gh` through stdin without logging it. The
preferred path is manifest conversion followed by the installer above.

```bash
read_multiline_secret() {
  local prompt="$1" terminator="$2" line secret='' terminated=false
  restore_terminal_echo() {
    stty echo < /dev/tty 2>/dev/null || true
  }
  printf '%s\n' "$prompt" >&2
  trap 'restore_terminal_echo; exit 130' INT TERM HUP
  trap 'restore_terminal_echo' EXIT
  if ! stty -echo < /dev/tty; then
    trap - EXIT INT TERM HUP
    return 1
  fi
  while IFS= read -r line < /dev/tty; do
    if [[ "$line" == "$terminator" ]]; then
      terminated=true
      break
    fi
    [[ -n "$secret" ]] && secret+=$'\n'
    secret+="$line"
  done
  restore_terminal_echo
  trap - EXIT INT TERM HUP
  if [[ "$terminated" != true ]]; then
    printf '\nSecret entry aborted: explicit terminator was not received.\n' >&2
    return 1
  fi
  printf '\n' >&2
  printf '%s' "$secret"
}

if ! writer_private_key="$(read_multiline_secret \
    'E2E Writer private key; finish with END-SECRET:' 'END-SECRET')"; then
  exit 1
fi
printf '%s' "$writer_private_key" | gh secret set \
  BOOTSTRAP_E2E_MAINTENANCE_WRITER_APP_PRIVATE_KEY \
  --repo OWNER/github-bootstrap --env e2e-maintenance
unset writer_private_key

if ! reviewer_private_key="$(read_multiline_secret \
    'E2E Reviewer private key; finish with END-SECRET:' 'END-SECRET')"; then
  exit 1
fi
printf '%s' "$reviewer_private_key" | gh secret set \
  BOOTSTRAP_E2E_MAINTENANCE_REVIEWER_APP_PRIVATE_KEY \
  --repo OWNER/github-bootstrap --env e2e-maintenance
unset reviewer_private_key

if ! e2e_client_secret="$(read_multiline_secret \
    'E2E provisioner client secret; finish with END-SECRET:' 'END-SECRET')"; then
  exit 1
fi
printf '%s' "$e2e_client_secret" | gh secret set \
  BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_SECRET \
  --repo OWNER/github-bootstrap --env e2e-testing
unset e2e_client_secret
```

The production provisioner client secret belongs to the separate
`production-provisioning` Environment:

```bash
if ! production_client_secret="$(read_multiline_secret \
    'Production provisioner client secret; finish with END-SECRET:' 'END-SECRET')"; then
  exit 1
fi
printf '%s' "$production_client_secret" | gh secret set \
  BOOTSTRAP_PRODUCTION_PROVISIONER_APP_CLIENT_SECRET \
  --repo OWNER/github-bootstrap --env production-provisioning
unset production_client_secret
```

The E2E maintenance Apps do not use client-secret or refresh-token secrets.
The canonical `e2e-maintenance` profiles contain only the client ID, slug, and
private key listed above. Client secrets and refresh tokens belong only to the
`e2e-provisioner` or `production-provisioner` profiles and their respective
Environments.

### 3.2 Rotation and reinstallation

On exposure, suspected exposure, ownership change, or scheduled rotation,
disable/revoke the old App credential in GitHub, create a new private key, and
rerun the matching manifest conversion and installer. Keep Writer and Reviewer
keys separate. Reinstall the rotated App only in the same disposable E2E owner,
then confirm its slug and client ID variables before rerunning verification.

For provisioner profiles, rerun `install-app-secrets.sh` with the same profile
and its newly generated local files. Personal-account runs rotate the refresh
token back into the same profile's Environment; never copy it between
`e2e-testing` and `production-provisioning`. Delete obsolete Environment
variables/secrets through GitHub's operator-controlled settings after the new
installation is verified. Do not print values while checking or deleting them.

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
Reviewer App token (`workflow-approval`),
and dispatches `Test Generated Repository E2E` against the PR head branch with
`head_sha` and `app_owner`. The workflow derives the E2E client ID from
`BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_ID` in the `e2e-testing` Environment. It
skips if a run for that exact head SHA already exists. `validate-maintenance-safety.sh`
then requires a successful E2E run whose `head_sha` equals the PR head.

## 5. Public E2E data and fork implications

- Generated E2E repositories are created **public** in the disposable E2E
  owner. Treat everything the E2E run produces as world-readable: run names,
  logs, generated files, and topics. Never feed real secrets or private
  templates into an E2E scenario.
- E2E repositories are marked with the `bootstrap-e2e` topic, **archived** as
  the first cleanup step, then deleted by the scheduled
  `Cleanup Archived E2E Repositories` workflow after **90 days**. Manual
  dispatch can override the retention period, including setting it to `0` for
  immediate cleanup.
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
  failure (missing/rotated `BOOTSTRAP_MAINTENANCE_REVIEWER_APP_PRIVATE_KEY`, App not
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
  of no-op: `BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_ID` unset in the `e2e-testing`
  Environment, Reviewer token resolve
  failed, or the head is a fork.
- Verify a `Test Generated Repository E2E` run exists whose `head_sha` matches
  the PR head. A run against `main` (wrong `--ref`) will not satisfy the gate.
- Manual fallback: run `Test Generated Repository E2E` via `workflow_dispatch`
  with `head_sha=<PR head>` and `app_owner=<owner>`. The workflow reads
  `BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_ID` from the `e2e-testing` Environment;
  it is not a dispatch input.

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

## 8. Manual dispatch and verification

Live dispatch is intentionally manual. It requires the operator to have
already provisioned the Apps and secrets, configured the allowlisted disposable
owner, and approved any protected Environment prompt. From the feature branch,
dispatch the focused scenario with non-secret inputs only:

```bash
repository="OWNER/github-bootstrap"
ref="feat/e2e-maintenance-apps"
owner="DISPOSABLE_E2E_OWNER"
head_sha="$(git rev-parse "$ref")"

gh workflow run test-generated-repository-e2e.yml --repo "$repository" --ref "$ref" \
  -f head_sha="$head_sha" \
  -f app_owner="$owner" \
  -f delivery=embedded \
  -f maintenance_lifecycle=true
```

The workflow reads `BOOTSTRAP_E2E_PROVISIONER_APP_CLIENT_ID` from
`e2e-testing`; `head_sha`, `app_owner`, and other dispatch fields are not secret
transport. The creation workflow copies/provisions the
`BOOTSTRAP_E2E_MAINTENANCE_*` credentials from the source
`OWNER/github-bootstrap` `e2e-maintenance` Environment into each generated
repository's matching Environment. The installer above is therefore run
against the source bootstrap repository, never directly against an already-
generated repository.
The E2E path must not read or fall back to `production-maintenance`.

Live verification remains pending and operator-controlled; this documentation
cleanup does not dispatch the workflow or automate approval.

Capture only the run URL and safe status fields, then verify the parent run and
its generated repository lifecycle:

```bash
gh run list --repo "$repository" --workflow test-generated-repository-e2e.yml --limit 5
gh run view RUN_ID --repo "$repository" --json status,conclusion,url
gh run view RUN_ID --repo "$repository" --log-failed
```

Verification is complete only when the parent run concludes `success`, the
maintenance PR is classified, reviewed, merged, and released by the expected
E2E Apps, and the generated repository is archived with the `bootstrap-e2e`
topic. A missing App installation, missing secret, failed Environment approval,
or absent disposable owner is an operator setup failure; fix it and rerun
manually.
