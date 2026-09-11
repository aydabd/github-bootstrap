#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "usage: $0 select|bind-e2e REPOSITORY_DIR WORKFLOWS [RELEASE_TOOL]" >&2
    exit 2
}

operation="${1:-}"
repository_dir="${2:-}"
workflows_input="${3:-}"
release_tool="${4:-git-cliff}"
if [ -z "$operation" ] || [ -z "$repository_dir" ] || [ -z "$workflows_input" ]; then
    usage
fi
[ -d "$repository_dir/.github/workflows" ] || {
    echo "workflow directory is missing: $repository_dir/.github/workflows" >&2
    exit 1
}

profile_loader="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/github-setup/app-credential-profile.sh"

normalize_workflows() {
    local raw_name normalized_name
    NORMALIZED_WORKFLOWS=()
    IFS=',' read -r -a raw_workflows <<< "$workflows_input"
    for raw_name in "${raw_workflows[@]}"; do
        normalized_name="${raw_name#"${raw_name%%[![:space:]]*}"}"
        normalized_name="${normalized_name%"${normalized_name##*[![:space:]]}"}"
        [ -n "$normalized_name" ] && NORMALIZED_WORKFLOWS+=("$normalized_name")
    done
}

has_workflow() {
    local candidate="$1" name
    for name in "${NORMALIZED_WORKFLOWS[@]}"; do
        [ "$name" = "$candidate" ] && return 0
    done
    return 1
}

maintenance_files=(
    quality.yml
    codeql.yml
    test-quality-providers.yml
    commit-policy.yml
    classify-maintenance-pr.yml
    maintenance-safety.yml
    approve-automation-workflows.yml
    merge-maintenance-pr.yml
)
maintenance_automation_files=(
    classify-maintenance-pr.yml
    maintenance-safety.yml
    approve-automation-workflows.yml
    merge-maintenance-pr.yml
)

release_file() {
    if [ "$release_tool" = "release-please" ]; then
        printf '%s\n' release-please.yml
    else
        printf '%s\n' git-cliff-release.yml
    fi
}

write_output() {
    [ -n "${GITHUB_OUTPUT:-}" ] || return 0
    printf 'quality_kept=%s\n' "$1" >> "$GITHUB_OUTPUT"
}

select_workflows() {
    local keep_files=" commit-policy.yml" quality_kept=false release_kept=false
    local valid_workflow_found=false name file filename
    normalize_workflows

    if has_workflow all || [ "${#NORMALIZED_WORKFLOWS[@]}" -eq 0 ]; then
        write_output true
        echo "Keeping all workflows"
        return 0
    fi

    if has_workflow none; then
        valid_workflow_found=true
    else
        for name in "${NORMALIZED_WORKFLOWS[@]}"; do
            case "$name" in
                quality)
                    keep_files="$keep_files quality.yml"
                    quality_kept=true
                    valid_workflow_found=true
                    ;;
                codeql | ai-code-review)
                    keep_files="$keep_files $name.yml"
                    valid_workflow_found=true
                    ;;
                maintenance)
                    quality_kept=true
                    for file in "${maintenance_files[@]}"; do
                        keep_files="$keep_files $file"
                    done
                    keep_files="$keep_files $(release_file)"
                    release_kept=true
                    valid_workflow_found=true
                    ;;
                release)
                    keep_files="$keep_files $(release_file)"
                    release_kept=true
                    valid_workflow_found=true
                    ;;
                *)
                    echo "warning: unknown workflow name '$name' (ignored)" >&2
                    ;;
            esac
        done
    fi

    [ "$valid_workflow_found" = true ] || {
        echo "no valid workflow names found in '$workflows_input'" >&2
        exit 1
    }

    for file in "$repository_dir"/.github/workflows/*.yml; do
        filename="${file##*/}"
        [[ " $keep_files " == *" $filename "* ]] && continue
        rm -f "$file"
    done

    write_output "$quality_kept"
    if [ "$release_kept" = false ]; then
        if [ "$release_tool" = "release-please" ]; then
            rm -f "$repository_dir/release-please-config.json" \
                "$repository_dir/.release-please-manifest.json"
        else
            rm -f "$repository_dir/cliff.toml"
        fi
    fi
}

bind_e2e() {
    local file substitutions release_path production_name e2e_name profile field
    local copilot_login="${E2E_COPILOT_REVIEWER_LOGIN:-}"
    [ -n "$copilot_login" ] || {
        echo "E2E Copilot reviewer login is required for E2E workflow binding" >&2
        exit 1
    }
    local release_files=("$(release_file)")
    normalize_workflows
    if has_workflow all || [ "${#NORMALIZED_WORKFLOWS[@]}" -eq 0 ]; then
        release_files=(release-please.yml git-cliff-release.yml)
    fi
    if has_workflow all || [ "${#NORMALIZED_WORKFLOWS[@]}" -eq 0 ] ||
        has_workflow maintenance; then
        for file in "${maintenance_automation_files[@]}" "${release_files[@]}"; do
            file="$repository_dir/.github/workflows/$file"
            [ -f "$file" ] || {
                echo "expected maintenance workflow is missing: $file" >&2
                exit 1
            }
            substitutions="$(sed -n 's/^    environment: production-maintenance$/    environment: e2e-maintenance/p' "$file")"
            if [ -n "$substitutions" ]; then
                sed -i.bak 's/^    environment: production-maintenance$/    environment: e2e-maintenance/' "$file"
            else
                release_path="/${file##*/}"
                case "$release_path" in
                    /release-please.yml | /git-cliff-release.yml)
                        sed -i.bak '/^    runs-on:/a\
    environment: e2e-maintenance
' "$file"
                        ;;
                    *)
                        echo "expected maintenance environment substitution missing: $file" >&2
                        exit 1
                        ;;
                esac
            fi
            sed -i.bak '/^    environment: e2e-maintenance$/a\
    env:\
        MAINTENANCE_IDENTITY_MODE: e2e-disposable\
        MAINTENANCE_FIXTURE_LOGIN: e2e-maintenance-user\
        MAINTENANCE_COPILOT_REVIEWER_LOGIN: '"$copilot_login"'\
' "$file"
            rm -f "$file.bak"
            sed -i.bak 's|COPILOT_REVIEWER_LOGIN: ${{ vars.BOOTSTRAP_COPILOT_REVIEWER_LOGIN }}|COPILOT_REVIEWER_LOGIN: ${{ env.MAINTENANCE_COPILOT_REVIEWER_LOGIN }}|' "$file"
            rm -f "$file.bak"
            for profile in e2e-maintenance-writer e2e-maintenance-reviewer; do
                for field in client_id_variable app_slug_variable private_key_secret; do
                    e2e_name="$(bash "$profile_loader" "$profile" "$field")"
                    production_name="${e2e_name/BOOTSTRAP_E2E_/BOOTSTRAP_}"
                    sed -i.bak "s/${production_name}/${e2e_name}/g" "$file"
                    rm -f "$file.bak"
                done
            done
            rm -f "$file.bak"
        done
    fi
}

case "$operation" in
    select) select_workflows ;;
    bind-e2e) bind_e2e ;;
    *) usage ;;
esac
