# GitHub App Manifest Personal E2E Design

## Goal

Provide a safe, repeatable bootstrap path for creating or configuring a GitHub App and obtaining a real personal-account App user token for the existing personal repository-creation workflow.

## Boundaries

- GitHub generates the App private key; local code never generates or fabricates one.
- The App uses `administration: write`, `contents: write`, and `issues: write`; metadata remains automatic read.
- `organization-administration` is excluded from the personal profile.
- Client ID is non-secret configuration. Private key, client secret, refresh token, and `ghu_` user token are never committed or passed as workflow inputs.
- Organization installation-token E2E remains pending because no disposable organization is available.

## Design

Add a local shell helper that creates a GitHub App Manifest authorization URL and a second command that exchanges the one-time conversion code with GitHub. The conversion response is stored only under a caller-selected 0700 directory, with the returned private key, client ID, and client secret written to separate 0600 files. This allows the caller to put the GitHub-generated private key into `BOOTSTRAP_PROVISIONER_APP_PRIVATE_KEY` without logging it.

Add a separate authorization helper that accepts the App client ID as an argument and the client secret through a protected file path, starts the GitHub App user OAuth flow, exchanges the callback code, verifies `/user` is the intended personal owner, and emits token metadata without the token value. Secret delivery remains an explicit `gh secret set` operation from protected files.

Add contract tests for manifest permissions, secret boundaries, token prefix/identity checks, and the absence of workflow-dispatch credential inputs. Add a credentialed personal E2E entry point that is manually dispatched with explicit personal-owner input and never falls back to PAT authentication.

## Failure handling

Every helper uses strict shell mode, validates owner and token identity before repository creation, rejects non-`ghu_` tokens, and refuses to print credentials. If GitHub authorization or protected secret delivery is unavailable, the live E2E exits before creating a repository.

## Verification

Run deterministic auth/profile contracts, helper shell syntax checks, YAML/action validation, complete `LINT_MODE=check make quality`, then the explicitly enabled personal E2E. Report organization E2E as pending.
