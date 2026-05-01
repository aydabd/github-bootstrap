#!/usr/bin/env bash
# =============================================================================
# sync-skills.sh — Ensure .claude/skills/ mirrors .github/skills/ (canonical)
# =============================================================================
# Usage:
#   ./scripts/sync-skills.sh [--check]
#
# Modes:
#   (default)  Recreate .claude/skills/ symlinks from .github/skills/
#   --check    Validate parity without modifying files (CI mode)
#
# The canonical source of truth for all skills is .github/skills/.
# Claude reads from .claude/skills/, which uses symlinks back to .github/.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

GITHUB_SKILLS="$ROOT_DIR/templates/.github/skills"
CLAUDE_SKILLS="$ROOT_DIR/templates/.claude/skills"

MODE="${1:-sync}"
ERRORS=0

if [ ! -d "$GITHUB_SKILLS" ]; then
    echo "ERROR: Canonical skill directory not found: $GITHUB_SKILLS"
    exit 1
fi

# ---------------------------------------------------------------------------
# Check mode: validate that every .github skill has a working .claude symlink
# ---------------------------------------------------------------------------
if [ "$MODE" = "--check" ]; then
    echo "Validating skill parity (.github/skills → .claude/skills)..."

    for skill_dir in "$GITHUB_SKILLS"/*/; do
        skill="$(basename "$skill_dir")"
        github_file="$GITHUB_SKILLS/$skill/SKILL.md"
        claude_file="$CLAUDE_SKILLS/$skill/SKILL.md"

        if [ ! -f "$github_file" ]; then
            continue
        fi

        if [ ! -e "$claude_file" ]; then
            echo "MISSING: .claude/skills/$skill/SKILL.md"
            ERRORS=$((ERRORS + 1))
            continue
        fi

        if [ -L "$claude_file" ]; then
            # Symlink — verify it resolves
            if [ ! -f "$claude_file" ]; then
                echo "BROKEN SYMLINK: .claude/skills/$skill/SKILL.md"
                ERRORS=$((ERRORS + 1))
            fi
        else
            # Regular file — check content matches
            if ! diff -q "$github_file" "$claude_file" > /dev/null 2>&1; then
                echo "DRIFT: .claude/skills/$skill/SKILL.md differs from .github/skills/$skill/SKILL.md"
                ERRORS=$((ERRORS + 1))
            fi
        fi
    done

    if [ "$ERRORS" -gt 0 ]; then
        echo ""
        echo "FAIL: $ERRORS skill parity issue(s) found."
        echo "Run: ./scripts/sync-skills.sh   to fix."
        exit 1
    fi

    echo "OK: All skills in sync."
    exit 0
fi

# ---------------------------------------------------------------------------
# Sync mode: recreate .claude/skills/ symlinks from .github/skills/
# ---------------------------------------------------------------------------
echo "Syncing .claude/skills/ symlinks from .github/skills/..."

for skill_dir in "$GITHUB_SKILLS"/*/; do
    skill="$(basename "$skill_dir")"
    github_file="$GITHUB_SKILLS/$skill/SKILL.md"
    claude_dir="$CLAUDE_SKILLS/$skill"
    claude_file="$claude_dir/SKILL.md"

    if [ ! -f "$github_file" ]; then
        continue
    fi

    mkdir -p "$claude_dir"

    # Remove existing file or symlink
    if [ -e "$claude_file" ] || [ -L "$claude_file" ]; then
        rm -f "$claude_file"
    fi

    # Create relative symlink
    ln -s "../../../.github/skills/$skill/SKILL.md" "$claude_file"
    echo "  ✓ $skill"
done

echo "Done. All .claude/skills/ entries are symlinks to .github/skills/."
