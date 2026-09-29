#!/usr/bin/env bash
set -euo pipefail
fail() {
    echo "Central capability canary contract failure: $*" >&2
    exit 1
}
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
validator="$root/scripts/github-setup/validate-central-capability-canary.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/valid.json" << 'EOF'
{"schema_version":1,"issue":357,"operator_gate":true,"validation":{"exact_head_shas":["0123456789012345678901234567890123456789"],"approval_actor":"governance[bot]","merge_actor":"writer[bot]","ruleset_state":"enforced","cleanup":{"performed":false,"owner_confirmation_required":true}},"rollback":{"bootstrap_runtime_ref":"main"}}
EOF
"$validator" --evidence-file "$tmp/valid.json" > /dev/null || fail "valid evidence was rejected"
for mutation in owner permissions credentials cleanup; do
    cp "$tmp/valid.json" "$tmp/mutated.json"
    case "$mutation" in
        owner) sed -i.bak 's/"issue":357/"issue":999/' "$tmp/mutated.json" ;;
        permissions) sed -i.bak 's/"operator_gate":true/"operator_gate":false/' "$tmp/mutated.json" ;;
        credentials) sed -i.bak 's/"bootstrap_runtime_ref":"main"/"bootstrap_runtime_ref":"refresh-token"/' "$tmp/mutated.json" ;;
        cleanup) sed -i.bak 's/"performed":false/"performed":true/' "$tmp/mutated.json" ;;
    esac
    if "$validator" --evidence-file "$tmp/mutated.json" > /dev/null; then
        fail "$mutation mutation was accepted"
    fi
done
grep -Fq 'operator-gated' "$root/templates/centralized-actions-workflows/README.md" || fail "README lacks operator-gated guidance"
grep -Fq 'rollback' "$root/templates/centralized-actions-workflows/README.md" || fail "README lacks rollback guidance"
echo "Central capability canary contract checks passed."
