#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cleanup-e2e-repositories-common.sh
# shellcheck disable=SC1091
source "$script_dir/cleanup-e2e-repositories-common.sh"

cleanup_archived_e2e_repositories "/orgs/$APP_OWNER/repos"
