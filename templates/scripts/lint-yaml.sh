#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "${1:-.}" && pwd)"
config_file="${2:-$repo_root/.github/linters/.yaml-lint.yml}"
ignore_file="${3:-$repo_root/.github/linters/.yaml-lint-ignore}"

[ -f "$config_file" ] || { echo "YAML lint configuration not found: $config_file" >&2; exit 1; }
[ -f "$ignore_file" ] || { echo "YAML lint ignore configuration not found: $ignore_file" >&2; exit 1; }

declare -a ignored_paths=()
while IFS= read -r ignored_path; do
    [ -n "$ignored_path" ] || continue
    [[ "$ignored_path" = \#* ]] && continue
    ignored_paths+=("$ignored_path")
done < "$ignore_file"

declare -a yaml_files=()
while IFS= read -r -d '' yaml_file; do
    relative_path="${yaml_file#"$repo_root/"}"
    excluded=false
    for ignored_path in "${ignored_paths[@]}"; do
        case "$relative_path" in
            "$ignored_path"|"$ignored_path"/*) excluded=true; break ;;
        esac
    done
    [ "$excluded" = false ] && yaml_files+=("$yaml_file")
done < <(find "$repo_root" -type f \( -name '*.yml' -o -name '*.yaml' \) -print0)

[ "${#yaml_files[@]}" -gt 0 ] || exit 0
yamllint --config-file "$config_file" "${yaml_files[@]}"
