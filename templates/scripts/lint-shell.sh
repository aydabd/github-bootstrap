#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "${1:-.}" && pwd)"
ignore_file="${2:-$repo_root/.github/linters/.shell-lint-ignore}"

[ -f "$ignore_file" ] || {
    echo "Shell lint ignore configuration not found: $ignore_file" >&2
    exit 1
}

declare -a ignored_paths=()
while IFS= read -r ignored_path; do
    [ -n "$ignored_path" ] || continue
    [[ "$ignored_path" = \#* ]] && continue
    ignored_paths+=("$ignored_path")
done < "$ignore_file"

declare -a shell_files=()
while IFS= read -r -d '' shell_file; do
    relative_path="${shell_file#./}"
    excluded=false
    for ignored_path in "${ignored_paths[@]}"; do
        case "$relative_path" in
            "$ignored_path" | "$ignored_path"/*)
                excluded=true
                break
                ;;
        esac
    done
    [ "$excluded" = false ] && shell_files+=("$repo_root/$relative_path")
done < <(
    cd "$repo_root"
    find . -type f \( -name '*.sh' -o -name '*.bash' \) -print0
)

[ "${#shell_files[@]}" -eq 0 ] || shellcheck "${shell_files[@]}"
