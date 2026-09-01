#!/usr/bin/env bash
set -euo pipefail

# Contract: uv is the only Python package manager. Micromamba and mise manage
# runtimes and non-Python binaries only; every Python package (pre-commit and
# the lint tools it drives) comes from a committed uv lockfile.
#
#   - no environment.yml declares a `pip` dependency or `pip:` section
#   - no mise install-tools task shells out to pip
#   - no setup-lint action installs Python tooling with pip
#   - every pyproject.toml has a sibling uv.lock
#   - every provider tree can reach a pyproject.toml (root or its language dir)

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

status=0
fail() {
    echo "uv-tooling contract: $1" >&2
    status=1
}

# ── environment.yml: no pip ────────────────────────────────────────────────────
while IFS= read -r env_file; do
    if grep -Eq '^\s*-\s*pip\s*$|^\s*-\s*pip:\s*$|^\s*pip:\s*$' "$env_file"; then
        fail "$env_file still declares a pip dependency or pip: section"
    fi
    if ! grep -Eq '^\s*-\s*uv([=<>! ]|$)' "$env_file"; then
        fail "$env_file does not manage uv"
    fi
done < <(find . -name environment.yml -not -path './.provider/*')

# ── mise.toml: install-tools must not call pip, must call uv sync ─────────────
while IFS= read -r mise_file; do
    if grep -Eq 'pip install|python -m pip|pip3 install' "$mise_file"; then
        fail "$mise_file install-tools task shells out to pip"
    fi
    if ! grep -q 'uv sync --locked' "$mise_file"; then
        fail "$mise_file does not run 'uv sync --locked'"
    fi
done < <(find . -name mise.toml -not -path './.provider/*')

# ── setup-lint actions: no pip for Python tooling ────────────────────────────
while IFS= read -r action_file; do
    if grep -Eq 'pip install|python[0-9.]* -m pip' "$action_file"; then
        fail "$action_file installs Python tooling with pip"
    fi
done < <(find . -path '*setup-lint-*/action.yml' -not -path './.provider/*')

# ── pyproject.toml <-> uv.lock parity ───────────────────────────────────────
while IFS= read -r proj; do
    dir="$(dirname "$proj")"
    [ -f "$dir/uv.lock" ] || fail "$proj has no sibling uv.lock (run: uv lock)"
done < <(find . -name pyproject.toml -not -path './.provider/*' -not -path '*/node_modules/*')

# ── root and every language template ship a locked uv project ────────────────
[ -f "$repo_root/pyproject.toml" ] || fail "root pyproject.toml is missing"
[ -f "$repo_root/uv.lock" ] || fail "root uv.lock is missing"
while IFS= read -r lang_dir; do
    [ -f "$lang_dir/pyproject.toml" ] || fail "$lang_dir/pyproject.toml is missing"
    [ -f "$lang_dir/uv.lock" ] || fail "$lang_dir/uv.lock is missing"
done < <(find templates/languages -mindepth 1 -maxdepth 1 -type d)

if [ "$status" -ne 0 ]; then
    echo "uv-tooling contract failed" >&2
    exit 1
fi
echo "uv Python-tooling contract checks passed."
