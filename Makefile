# =============================================================================
# GitHub Bootstrap — Makefile
# =============================================================================
# Zero manual setup — `make install` bootstraps everything automatically:
#   1. Bootstraps selected env manager tooling if needed (micromamba, mise, or system)
#   2. Installs pre-commit Git hooks
#
# Quick start:
#   make install              Bootstrap env + hooks
#   make lint                 Auto-format + lint (local dev)
#   LINT_MODE=check make lint Check-only (CI mode, no auto-fix)
#   make test                 Trigger repository creation tests
#
# Env manager options:
#   ENV_MANAGER=micromamba (default)
#   ENV_MANAGER=mise
#   ENV_MANAGER=system
# =============================================================================

include make/common.mk
include make/help.mk
include make/env.mk
include make/lint.mk
include make/test.mk
include make/tooling.mk
include make/clean.mk
