#!/usr/bin/env bash
set -euo pipefail

workflow="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.github/workflows/conda-lock.yml"
grep -Fq 'ubuntu-24.04' "$workflow"
grep -Fq 'macos-26-intel' "$workflow"
grep -Fq 'macos-26' "$workflow"
grep -Fq 'conda-lock==4.0.2' "$(dirname "$workflow")/../../scripts/generate-conda-lock.sh"
if grep -Eq 'macos-1[0-9]|macos-latest' "$workflow"; then
    echo "workflow uses an older or floating macOS runner" >&2
    exit 1
fi
grep -Fq 'merge-conda-locks.py' "$workflow"
grep -Fq 'native-locks/conda-lock-linux-64/$lock_name' "$workflow"
if grep -Fq 'native-locks/conda-lock-linux-64/locks/$lock_name' "$workflow"; then
    echo "workflow assumes upload-artifact preserves the source directory" >&2
    exit 1
fi
echo "Conda lock workflow contract checks passed."
