#!/usr/bin/env bash
set -euo pipefail

# Contract: every external pre-commit hook repo is pinned to an immutable
# 40-hex commit SHA, never a movable tag. Applies to the root config, the
# agnostic base template, and every rendered template config. All configs must
# agree on the SHA for a given repo (root/template parity).

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

configs=(
    "$repo_root/.pre-commit-config.yaml"
    "$repo_root/templates/languages/agnostic/pre-commit-snippets/base.tmpl"
)
while IFS= read -r rendered; do
    configs+=("$rendered")
done < <(find "$repo_root/templates/languages" -name '.pre-commit-config.yaml' | sort)

status=0
# newline-separated "url<TAB>sha" records of the first pin seen for each url
seen=""

for config in "${configs[@]}"; do
    [ -f "$config" ] || {
        echo "missing pre-commit config: $config" >&2
        status=1
        continue
    }
    rel="${config#"$repo_root"/}"

    # Walk "- repo: <url>" / "rev: <value>" pairs. repo: local has no rev and is
    # skipped implicitly because the next repo entry resets the pending url.
    current_repo=""
    while IFS= read -r line; do
        case "$line" in
            *"- repo: "*)
                current_repo="${line#*- repo: }"
                current_repo="${current_repo%%[[:space:]]*}"
                ;;
            *"rev: "*)
                [ -n "$current_repo" ] || continue
                [ "$current_repo" != "local" ] || continue
                rev="${line#*rev: }"
                sha="${rev%%[[:space:]]*}"
                if ! printf '%s' "$sha" | grep -Eq '^[0-9a-f]{40}$'; then
                    echo "$rel: $current_repo pinned by non-SHA rev '$sha'" >&2
                    status=1
                else
                    prior="$(printf '%s\n' "$seen" | awk -v u="$current_repo" -F '\t' '$1 == u {print $2; exit}')"
                    if [ -n "$prior" ] && [ "$prior" != "$sha" ]; then
                        echo "$rel: $current_repo SHA '$sha' disagrees with '$prior' elsewhere" >&2
                        status=1
                    elif [ -z "$prior" ]; then
                        seen="$seen$current_repo	$sha
"
                    fi
                fi
                current_repo=""
                ;;
        esac
    done < "$config"
done

if [ "$status" -ne 0 ]; then
    echo "pre-commit SHA-pin contract failed" >&2
    exit 1
fi

echo "pre-commit SHA-pin contract checks passed."
