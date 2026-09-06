#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="$repo_root/.github/workflows/weekly-tooling-updates.yml"
refresh="$repo_root/scripts/regenerate-tooling-locks.sh"
drift="$repo_root/scripts/validate-tooling-lock-drift.sh"

[ -f "$refresh" ] || {
    echo "missing unified tooling lock refresh script" >&2
    exit 1
}
[ -f "$drift" ] || {
    echo "missing tooling manifest/lockfile drift validator" >&2
    exit 1
}

grep -Fq 'scripts/regenerate-tooling-locks.sh' "$workflow" || {
    echo "weekly workflow does not use the unified lock refresh" >&2
    exit 1
}
for command in 'conda-lock' 'mise lock' 'npm ci' 'uv lock --upgrade' 'pre-commit autoupdate --freeze'; do
    grep -Fq "$command" "$refresh" || {
        echo "unified lock refresh does not invoke: $command" >&2
        exit 1
    }
done
grep -Fq '14' "$workflow" || {
    echo "weekly workflow does not preserve the cooldown configuration" >&2
    exit 1
}
grep -Fq 'TOOLING_UPDATE_METADATA_FILE' "$workflow" || {
    echo "weekly workflow does not pass tooling metadata" >&2
    exit 1
}
grep -Fq 'scripts/validate-tooling-lock-drift.sh' "$workflow" || {
    echo "weekly workflow does not reject manifest/lockfile drift" >&2
    exit 1
}
grep -Fq 'trap restore ERR' "$refresh" || {
    echo "lock refresh is not transactional" >&2
    exit 1
}
if ! grep -Fq 'dirname "' "$drift" || ! grep -Fq 'relative")' "$drift"; then
    echo "drift validator does not derive sibling lock paths safely" >&2
    exit 1
fi
grep -Fq 'git diff HEAD --name-only' "$drift" || {
    echo "drift validator does not combine staged and unstaged changes" >&2
    exit 1
}
grep -Fq 'bootstrap-provider-binary.sh' "$repo_root/scripts/regenerate-mise-locks.sh" || {
    echo "mise refresh no longer bootstraps the verified project-local tool" >&2
    exit 1
}
grep -Fq 'conda-lock' "$refresh" || {
    echo "unified refresh does not document its conda-lock invocation" >&2
    exit 1
}
grep -Fq 'lockfile' "$repo_root/scripts/github-setup/validate-tooling-metadata.sh" || {
    echo "metadata validator does not classify lockfile updates" >&2
    exit 1
}

echo "Weekly tooling lock refresh contract checks passed."
