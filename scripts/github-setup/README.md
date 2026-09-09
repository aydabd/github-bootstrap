# GitHub Setup Scripts

This folder contains local `gh`-based setup scripts for applying selected GitHub
repository configuration without running setup workflows.

Requirements:

- Bash
- GitHub CLI (`gh`)
- `jq`

Authenticate with `gh auth login` or set `GH_TOKEN` before running a script. Use
`GH_HOST` with `gh` for GitHub Enterprise Server. The authenticated token must
have access to administer the target repository.

## Scripts

| Script                        | Purpose                       |
| ----------------------------- | ----------------------------- |
| `setup-labels.sh`             | Labels                        |
| `setup-security-settings.sh`  | Security settings             |
| `setup-repo-settings.sh`      | Repository settings           |
| `setup-ruleset.sh`            | Repository rulesets           |
| `validate-profile.sh`         | Bootstrap profile validation  |
| `test-local-setup-scripts.sh` | Test-only live E2E assertions |

Each script's `--help` output is the source of truth for options, defaults, and
examples. Update the script help when behavior changes instead of duplicating
usage commands in this README.

Shared helpers live in `gh-common.sh`. Keep only cross-script concerns there,
such as required input checks, file checks, GitHub API endpoint construction,
JSON key reads, URL encoding, and known GitHub plan or feature limitation
detection.

## Bootstrap profiles

The canonical profile manifest is
`templates/.github/config/bootstrap-profile.json`. It classifies generated
assets as `baseline`, `optional:<bundle>`, or `provider-specific`, and defines
the stable quality capability names used by generated workflows and rulesets.

Validate a profile before applying it:

```bash
scripts/github-setup/validate-profile.sh \
  --profile-file templates/.github/config/bootstrap-profile.json \
  --profile baseline \
  --delivery-mode embedded
```

The default profile does not include the optional planning bundle. Centralized
delivery requires a user-owned repository and immutable ref; existing
repositories are not modified automatically.

## Centralized monorepo E2E

Run `make test-centralized-monorepo` to create a temporary central workflow
repository and a separate `languages=all` consumer. The scenario captures the
central seed commit SHA, configures the consumer to use that immutable ref,
validates the generated profile and ruleset, and waits for consumer quality to
pass.

The target preserves both repositories for inspection. Delete them explicitly
when finished with the commands printed in the workflow summary:

```bash
gh repo delete OWNER/bootstrap-e2e-<timestamp>-system-centralized-create-repository --yes
gh repo delete OWNER/bootstrap-e2e-<timestamp>-system-centralized-central-workflows --yes
```

If the scenario fails, its guarded cleanup job deletes both generated
repositories when cleanup is enabled. Only the names emitted by the scenario
are passed to the cleanup token.

## Live Verification

Use the manual [.github/workflows/test-local-setup-scripts.yml](../../.github/workflows/test-local-setup-scripts.yml)
workflow to verify these scripts against real GitHub APIs. It delegates script
execution and API assertions to the test-only
[.github/actions/test-local-setup-scripts](../../.github/actions/test-local-setup-scripts)
composite action.
