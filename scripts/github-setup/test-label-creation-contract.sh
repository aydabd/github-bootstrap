#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
setup_script="$script_dir/setup-labels.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin"
cat > "$tmp_dir/bin/gh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

method=GET
endpoint=""
for ((index = 1; index <= $#; index++)); do
    argument="${!index}"
    case "$argument" in
        --method)
            next=$((index + 1))
            method="${!next}"
            ;;
        /repos/*)
            endpoint="$argument"
            ;;
    esac
done

case "$method $endpoint" in
    "GET /repos/aydabd/github-bootstrap/labels/"*)
        printf '%s\n' '{"message":"Not Found"}'
        exit 1
        ;;
    "POST /repos/aydabd/github-bootstrap/labels")
        printf '%s\n' POST >> "$GH_LABEL_CALLS"
        printf '%s\n' '{}'
        ;;
    *)
        echo "unexpected gh call: $method $endpoint" >&2
        exit 1
        ;;
esac
EOF
chmod 700 "$tmp_dir/bin/gh"

cat > "$tmp_dir/labels.json" << 'EOF'
{"labels":[{"name":"automation: maintenance","color":"0366d6","description":"Automated maintenance update"}]}
EOF
: > "$tmp_dir/calls"

if PATH="$tmp_dir/bin:$PATH" GH_LABEL_CALLS="$tmp_dir/calls" \
    bash "$setup_script" --owner aydabd --repo github-bootstrap \
    --label-file "$tmp_dir/labels.json" > /dev/null; then
    actual_calls="$(cat "$tmp_dir/calls")"
    [ "$actual_calls" = POST ] || {
        echo "expected a POST when a label lookup returns 404" >&2
        exit 1
    }
else
    echo "setup-labels.sh failed to create a missing label" >&2
    exit 1
fi

echo "Missing label creation contract passed."
