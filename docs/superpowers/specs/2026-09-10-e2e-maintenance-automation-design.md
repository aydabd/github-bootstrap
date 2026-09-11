# E2E Maintenance Automation Design

## Goal

Enable generated E2E repositories to exercise the same maintenance lifecycle as
the dogfooding repository without granting E2E workflows access to production
maintenance credentials.

## Boundaries

Production maintenance workflows and the `production-maintenance` environment
remain unchanged. This change adds an isolated E2E maintenance path and makes
Terraform-generated repositories retain the maintenance workflow chain.

## Architecture

Two dedicated GitHub Apps are used only in the disposable E2E owner:

- E2E Maintenance Writer: labels eligible maintenance pull requests, creates
  Release Please updates, and enables squash auto-merge after validation.
- E2E Maintenance Reviewer: approves eligible maintenance pull requests and
  workflow runs after required checks and Copilot review validation.

Generated E2E repositories use an `e2e-maintenance` GitHub Environment. The
environment contains the E2E Writer and Reviewer client IDs/slugs as variables
and private keys as secrets. Production credentials remain in
`production-maintenance` and are never copied or referenced by E2E workflows.

The credential names remain role-specific and stable. Only the environment
binding changes between production and E2E. Workflow files use the explicit
environment selected for the repository; no fallback to production credentials
is permitted.

## Provisioning flow

The E2E setup provisions the two Apps from checked-in manifests, installs them
only in the disposable E2E owner, and configures their installation access for
generated repositories. The generated-repository creation workflow writes the
non-secret App configuration and encrypted private keys to the generated
repository's `e2e-maintenance` Environment using the isolated E2E provisioning
authority. Private keys are never placed in repository contents, workflow
inputs, logs, or generated files.

## Workflow behavior

Terraform and standard repository creation retain the maintenance workflow chain
when maintenance automation is requested. For E2E scenarios, the generated
repository receives the chain configured for `e2e-maintenance`:

1. Dependabot or Release Please opens a pull request.
2. The Writer classifies and labels the pull request.
3. Quality, security, and repository policy checks complete.
4. Copilot review exists, its threads are resolved, and required review gates
   pass.
5. The Reviewer approves the maintenance pull request or eligible workflow.
6. The Writer enables squash auto-merge after fresh validation.
7. Release Please uses the Writer identity for release pull requests and tags.

The E2E workflow validates the resulting PR labels, App identities, required
checks, review state, merge state, and release behavior. It archives generated
repositories through the existing guarded lifecycle path.

## Safety requirements

- E2E Writer and Reviewer Apps have separate keys and permissions.
- E2E Apps are installed only in the allowlisted disposable owner.
- Production-maintenance credentials are never readable by E2E jobs.
- No App bypasses repository rulesets or required reviews.
- Repository and environment names are validated before credential writes.
- Cleanup remains restricted to generated names, the `bootstrap-e2e` topic, and
  archived repositories.
- Missing E2E maintenance credentials fail explicitly; workflows do not silently
  fall back to production or the default token.

## Verification

Static contracts will verify profile names, environment bindings, manifests,
permission boundaries, workflow retention, and absence of production credential
references in the E2E path. Live verification will use a generated repository
and confirm the full Dependabot/Release Please maintenance chain, including
quality checks, Copilot review validation, Reviewer approval, Writer auto-merge,
and guarded archive cleanup.
