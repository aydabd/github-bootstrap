#!/usr/bin/env bash

cleanup_archived_e2e_repositories() {
    local repositories_endpoint="${1:-}"
    local validator="${VALIDATOR:-}"
    local tmp_dir
    local exclusions
    local now_epoch
    local repositories_file
    local scanned=0
    local eligible=0
    local deleted=0
    local already_gone=0
    local failures=0
    local deleted_names=""
    local min_age_days="${MIN_AGE_DAYS:-90}"

    if [ -z "$repositories_endpoint" ] || [ -z "${E2E_GH_TOKEN:-}" ] ||
        [ -z "${ALLOWED_OWNERS:-}" ] || [ -z "${APP_OWNER:-}" ] ||
        [ -z "${CENTRAL_REPOSITORY:-}" ] || [ -z "${BOOTSTRAP_REPOSITORY:-}" ] ||
        [ -z "$validator" ]; then
        echo "E2E cleanup configuration is incomplete" >&2
        return 1
    fi
    [[ "$min_age_days" =~ ^[0-9]+$ ]] || {
        echo "minimum E2E repository age is invalid" >&2
        return 1
    }
    if [ ! -x "$validator" ]; then
        echo "E2E cleanup validator is not executable: $validator" >&2
        return 1
    fi
    [[ "$APP_OWNER" =~ ^[A-Za-z0-9_.-]+$ ]] || {
        echo "E2E App owner is missing or invalid" >&2
        return 1
    }
    [ -n "$ALLOWED_OWNERS" ] || {
        echo "E2E cleanup allowlist is empty; refusing to continue" >&2
        return 1
    }
    owner_is_allowed=false
    IFS=',' read -ra allowed_owner_values <<< "$ALLOWED_OWNERS"
    for allowed_owner in "${allowed_owner_values[@]}"; do
        allowed_owner="${allowed_owner//[[:space:]]/}"
        if [ "$allowed_owner" = "$APP_OWNER" ]; then
            owner_is_allowed=true
        fi
    done
    [ "$owner_is_allowed" = true ] || {
        echo "E2E App owner is not present in the cleanup allowlist" >&2
        return 1
    }
    [[ "$CENTRAL_REPOSITORY" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || {
        echo "central workflow repository exclusion is missing or invalid" >&2
        return 1
    }

    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    exclusions="$BOOTSTRAP_REPOSITORY,$CENTRAL_REPOSITORY"
    now_epoch="$(date -u '+%s')"
    repositories_file="$tmp_dir/repositories.json"
    if ! GH_TOKEN="$E2E_GH_TOKEN" gh api --paginate --slurp \
        "$repositories_endpoint?type=all&per_page=100" > "$repositories_file"; then
        echo "failed to enumerate E2E repositories" >&2
        return 1
    fi

    while IFS= read -r repository; do
        [ -n "$repository" ] || continue
        scanned=$((scanned + 1))
        owner="$(jq -r '.owner.login // empty' <<< "$repository")"
        name="$(jq -r '.name // empty' <<< "$repository")"
        full_name="$owner/$name"
        candidate_file="$tmp_dir/candidate.json"
        probe_file="$tmp_dir/probe-response"
        if GH_TOKEN="$E2E_GH_TOKEN" gh api --include \
            "/repos/$full_name" > "$probe_file" 2>&1; then
            sed -n '/^{/,$p' "$probe_file" > "$candidate_file"
        elif grep -Eq '^HTTP/[0-9.]+ 404' "$probe_file"; then
            continue
        else
            echo "failed to re-fetch E2E repository $full_name before validation" >&2
            return 1
        fi

        if ! "$validator" "$ALLOWED_OWNERS" "$candidate_file" "$exclusions" "$now_epoch" "$min_age_days"; then
            continue
        fi

        eligible=$((eligible + 1))
        response_file="$tmp_dir/delete-response"
        if GH_TOKEN="$E2E_GH_TOKEN" gh api --include --method DELETE \
            "/repos/$full_name" > "$response_file" 2>&1; then
            deleted=$((deleted + 1))
            deleted_names="$deleted_names $full_name"
            continue
        fi
        if grep -Eq '^HTTP/[0-9.]+ 404' "$response_file"; then
            already_gone=$((already_gone + 1))
            continue
        fi
        echo "failed to delete validated E2E repository $full_name" >&2
        failures=$((failures + 1))
    done < <(jq -c '.[][]' "$repositories_file")

    summary_file="${GITHUB_STEP_SUMMARY:-/dev/null}"
    {
        echo "## Archived E2E repository cleanup"
        echo "- Scanned: $scanned"
        echo "- Eligible: $eligible"
        echo "- Deleted: $deleted"
        echo "- Already absent: $already_gone"
        echo "- Skipped: $((scanned - eligible))"
        echo "- Failures: $failures"
        [ -n "$deleted_names" ] && echo "- Deleted repositories:$deleted_names"
    } >> "$summary_file"

    [ "$failures" -eq 0 ]
}
