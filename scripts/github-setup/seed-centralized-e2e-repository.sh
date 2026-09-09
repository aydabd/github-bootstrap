#!/usr/bin/env bash
set -euo pipefail

owner=""
repository=""
seed_root=""

usage() {
    cat << 'USAGE'
Usage: seed-centralized-e2e-repository.sh --owner OWNER --repository NAME --seed-root PATH
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --owner)
            owner="${2:-}"
            shift 2
            ;;
        --repository)
            repository="${2:-}"
            shift 2
            ;;
        --seed-root)
            seed_root="${2:-}"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [ -z "$owner" ] || [ -z "$repository" ] || [ ! -d "$seed_root" ]; then
    echo "owner, repository, and an existing seed root are required" >&2
    exit 1
fi
if ! [[ "$owner" =~ ^[A-Za-z0-9_.-]+$ ]] || ! [[ "$repository" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    echo "owner and repository contain invalid characters" >&2
    exit 1
fi
command -v gh > /dev/null || {
    echo "gh is required" >&2
    exit 1
}
command -v git > /dev/null || {
    echo "git is required" >&2
    exit 1
}

for workflow in "$seed_root"/.github/workflows/*.yml; do
    grep -q '^  workflow_call:' "$workflow" || {
        echo "central seed workflow is not reusable: $workflow" >&2
        exit 1
    }
    if grep -Eq '^  (push|pull_request|workflow_dispatch):' "$workflow"; then
        echo "central seed workflow has a repository event trigger: $workflow" >&2
        exit 1
    fi
done

gh repo create "$owner/$repository" --public --description "Temporary centralized workflow seed for GitHub Bootstrap E2E"

temporary_root="$(mktemp -d)"
cleanup() { rm -rf "$temporary_root"; }
trap cleanup EXIT
cp -R "$seed_root"/. "$temporary_root"/
git -C "$temporary_root" init --initial-branch=main > /dev/null
git -C "$temporary_root" config user.name "github-bootstrap-e2e"
git -C "$temporary_root" config user.email "github-bootstrap-e2e@users.noreply.github.com"
git -C "$temporary_root" add .
git -C "$temporary_root" commit -m "chore: seed centralized workflows" > /dev/null
git -C "$temporary_root" remote add origin "https://github.com/$owner/$repository.git"
git -C "$temporary_root" push "https://x-access-token:${GH_TOKEN}@github.com/$owner/$repository.git" main > /dev/null

commit_sha="$(git -C "$temporary_root" rev-parse HEAD)"
echo "repository=$owner/$repository" >> "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
echo "ref=$commit_sha" >> "$GITHUB_OUTPUT"
echo "Central workflow seed published at $owner/$repository@$commit_sha"
