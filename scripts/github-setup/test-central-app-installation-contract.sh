#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
validator="$script_dir/validate-central-app-installation.sh"

fail() {
    echo "central App installation contract: $*" >&2
    exit 1
}

test -x "$validator" || fail "installation validator is not executable"

fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT
fake_bin="$fixture_root/bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/gh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' '{"repositories":[{"full_name":"owner/canary"},{"full_name":"other/visible"}]}'
EOF
chmod 700 "$fake_bin/gh"

output="$(PATH="$fake_bin:$PATH" GH_TOKEN=installation-token \
    "$validator" central-production-governance owner/canary other/hidden)"
printf '%s' "$output" | jq -e '
    .schema_version == 1 and .result == "PASS" and
    .role == "central-production-governance" and
    .repository == "owner/canary" and
    .forbidden_repositories == ["other/hidden"] and
    .checks == [
        {result:"PASS", check:"target-visible"},
        {result:"PASS", check:"forbidden-repositories-hidden"}
    ] and
    .summary == {passed:2, failed:0, skipped:0}
' > /dev/null || fail "successful scope validation did not emit the contract"

if printf '%s' "$output" | grep -Eiq 'installation-token|gho_|ghu_|ghr_|private.key|secret'; then
    fail "scope validation output contains credential-like material"
fi

set +e
missing_output="$(PATH="$fake_bin:$PATH" GH_TOKEN=installation-token \
    "$validator" central-production-governance owner/missing other/hidden 2> "$fixture_root/missing.err")"
missing_status="$?"
set -e
[ "$missing_status" -eq 1 ] || fail "missing target must fail"
printf '%s' "$missing_output" | jq -e '.result == "FAIL" and .checks[0].check == "target-visible" and .checks[0].error_code == "TARGET_NOT_VISIBLE"' > /dev/null ||
    fail "missing target failure is not deterministic"

if PATH="$fake_bin:$PATH" env -u GH_TOKEN "$validator" central-production-governance owner/canary > /dev/null 2> "$fixture_root/token.err"; then
    fail "missing installation token must fail"
fi
grep -Fq 'GH_TOKEN must be set' "$fixture_root/token.err" || fail "missing token remediation is absent"

if PATH="$fake_bin:$PATH" GH_TOKEN=installation-token "$validator" production-writer owner/canary > /dev/null 2> "$fixture_root/role.err"; then
    fail "bootstrap role must be rejected"
fi
grep -Fq 'central runtime role' "$fixture_root/role.err" || fail "role boundary remediation is absent"

echo "Central App installation contract checks passed."
