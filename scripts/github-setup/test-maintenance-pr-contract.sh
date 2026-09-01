#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
validator="$script_dir/validate-maintenance-pr.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$tmp_dir/dependabot.json" << 'EOF'
{"state":"open","draft":false,"user":{"login":"dependabot[bot]"},"head":{"repo":{"full_name":"acme/project"}},"base":{"ref":"main","repo":{"full_name":"acme/project"}},"labels":[{"name":"dependencies"}]}
EOF
cat > "$tmp_dir/release-please.json" << 'EOF'
{"state":"open","draft":false,"user":{"login":"release-please[bot]"},"head":{"repo":{"full_name":"acme/project"}},"base":{"ref":"main","repo":{"full_name":"acme/project"}},"labels":[{"name":"autorelease: pending"}]}
EOF
cat > "$tmp_dir/writer-release.json" << 'EOF'
{"state":"open","draft":false,"user":{"login":"acme-maintenance-writer[bot]"},"head":{"repo":{"full_name":"acme/project"}},"base":{"ref":"main","repo":{"full_name":"acme/project"}},"labels":[{"name":"autorelease: pending"}]}
EOF

expected_dependabot="dependabot"
actual_dependabot="$(FULL_REPOSITORY=acme/project "$validator" "$tmp_dir/dependabot.json")"
[ "$actual_dependabot" = "$expected_dependabot" ]

expected_release="release-please"
actual_release="$(FULL_REPOSITORY=acme/project "$validator" "$tmp_dir/release-please.json")"
[ "$actual_release" = "$expected_release" ]

# release-please runs as the Maintenance Writer App: its PR is authored by
# "<writer-app-slug>[bot]" and must classify as release-please when the slug is
# supplied, but not otherwise.
actual_writer="$(FULL_REPOSITORY=acme/project WRITER_APP_SLUG=acme-maintenance-writer \
    "$validator" "$tmp_dir/writer-release.json")"
[ "$actual_writer" = "release-please" ]

if FULL_REPOSITORY=acme/project "$validator" "$tmp_dir/writer-release.json"; then
    echo "validator accepted a writer-app release PR without WRITER_APP_SLUG" >&2
    exit 1
fi

for mutation in fork closed draft author release-label base; do
    case "$mutation" in
        fork) sed 's#acme/project#other/project#g' "$tmp_dir/dependabot.json" > "$tmp_dir/mutated.json" ;;
        closed) sed 's/"state":"open"/"state":"closed"/' "$tmp_dir/dependabot.json" > "$tmp_dir/mutated.json" ;;
        draft) sed 's/"draft":false/"draft":true/' "$tmp_dir/dependabot.json" > "$tmp_dir/mutated.json" ;;
        author) sed 's/dependabot\[bot\]/unknown[bot]/' "$tmp_dir/dependabot.json" > "$tmp_dir/mutated.json" ;;
        release-label) sed 's/"autorelease: pending"/"dependencies"/' "$tmp_dir/release-please.json" > "$tmp_dir/mutated.json" ;;
        base) sed 's/"main"/"develop"/' "$tmp_dir/dependabot.json" > "$tmp_dir/mutated.json" ;;
    esac
    if FULL_REPOSITORY=acme/project "$validator" "$tmp_dir/mutated.json"; then
        echo "validator accepted invalid fixture: $mutation" >&2
        exit 1
    fi
done

echo "Maintenance PR contract passed."
