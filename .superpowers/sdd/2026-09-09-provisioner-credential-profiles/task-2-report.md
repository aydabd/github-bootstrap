# Task 2 report

Implemented profile-aware, environment-scoped App credential installation.

## RED

Added contract assertions for the six-argument interface, Task 1 profile
loader resolution, environment-scoped GitHub commands, manifest-derived names,
and removal of legacy hardcoded names.

Command:

```text
bash scripts/github-setup/test-install-app-secrets-contract.sh
```

Output:

```text
exit=1
```

The contract failed because the installer still exposed the five-argument
interface and hardcoded the legacy credential names.

## GREEN

Updated `install-app-secrets.sh` to accept:

```text
install-app-secrets.sh REPOSITORY PROFILE CLIENT_ID_FILE PRIVATE_KEY_FILE CLIENT_SECRET_FILE REFRESH_TOKEN_FILE
```

It resolves the five profile fields once through
`app-credential-profile.sh`, validates the supplied files, and installs the
client ID as an environment variable and the three credentials as environment
secrets using the resolved manifest names.

Command:

```text
bash scripts/github-setup/test-install-app-secrets-contract.sh && shellcheck scripts/github-setup/install-app-secrets.sh
```

Output:

```text
exit=0
App secret installer contract checks passed.
```

Additional verification:

```text
bash -n scripts/github-setup/install-app-secrets.sh scripts/github-setup/test-install-app-secrets-contract.sh
git diff --check
```

Both commands completed successfully with no output.

## Fix round 1

Updated the installer help text to describe the six-argument profile-aware
interface and environment-only variable/secret installation. Extended the
contract with a deterministic executable test that creates valid temporary
credential files, prepends a fake `gh` that records calls and fails, invokes
an unknown profile, asserts rejection and the loader error, and asserts zero
fake-`gh` calls.

### Fix-round RED

Command:

```text
bash scripts/github-setup/test-install-app-secrets-contract.sh
```

Output:

```text
exit=1
```

The contract failed at the new help-text assertion. The unknown-profile
behavior already rejected before `gh` in the current implementation, so that
new executable assertion could not produce a meaningful RED failure without
regressing the existing implementation.

### Fix-round GREEN

Command:

```text
bash scripts/github-setup/test-install-app-secrets-contract.sh && shellcheck scripts/github-setup/install-app-secrets.sh scripts/github-setup/test-install-app-secrets-contract.sh
```

Output:

```text
exit=0
App secret installer contract checks passed.
```

Additional verification:

```text
bash -n scripts/github-setup/install-app-secrets.sh scripts/github-setup/test-install-app-secrets-contract.sh
git diff --check
```

Both commands completed successfully with no output.
