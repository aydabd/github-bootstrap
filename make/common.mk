# =============================================================================
# Common Configuration
# =============================================================================
.DEFAULT_GOAL := help

SHELL := /bin/bash

.SUFFIXES:
.DELETE_ON_ERROR:
MAKEFLAGS += --no-builtin-rules

CORE_TARGETS := help
ENV_TARGETS := setup-env install install-hooks
QUALITY_TARGETS := lint test
QUALITY_TARGETS += test-api-default test-terraform-default
QUALITY_TARGETS += test-api-no-repo-settings test-terraform-no-repo-settings
QUALITY_TARGETS += test-api-all-languages test-terraform-all-languages
TOOLING_TARGETS := tooling-updater-build tooling-update-repo tooling-update-templates tooling-update-all tooling-update-micromamba tooling-update-mise tooling-update-system tooling-update-precommit tooling-verify
TEMPLATE_TARGETS := render-precommit
MAINTENANCE_TARGETS := clean verify-makefile verify-template-makefiles
PUBLIC_TARGETS := $(CORE_TARGETS) $(ENV_TARGETS) $(QUALITY_TARGETS) $(TOOLING_TARGETS) $(TEMPLATE_TARGETS) $(MAINTENANCE_TARGETS)
INTERNAL_TARGETS := _install-hooks

.PHONY: $(PUBLIC_TARGETS) $(INTERNAL_TARGETS)

MAMBA_ENV  := github-bootstrap
MAMBA_SPEC := $(CURDIR)/environment.yml
MICROMAMBA ?= $(CURDIR)/.provider/bin/micromamba
MISE ?= $(CURDIR)/.provider/bin/mise

# LINT_MODE: fix (default, local dev) or check (CI, no auto-fix)
LINT_MODE ?= fix
SHOW_COMMANDS ?= 1

ifeq ($(SHOW_COMMANDS),1)
SETUP_TRACE := set -x;
CMD_ECHO := echo
else
SETUP_TRACE :=
CMD_ECHO := :
endif

# Backward compatibility:
# USE_MAMBA=0 implies ENV_MANAGER=system.
USE_MAMBA ?= 1

ENV_MANAGER ?= micromamba

ifeq ($(USE_MAMBA),0)
ifeq ($(origin ENV_MANAGER),default)
ENV_MANAGER := system
endif
endif

ifeq ($(ENV_MANAGER),micromamba)
RUN := $(MICROMAMBA) run -n $(MAMBA_ENV)
else ifeq ($(ENV_MANAGER),mise)
RUN := $(MISE) exec --
else
RUN :=
endif

# Build directory for stamp files
BUILD_DIR := build
TOOLING_UPDATER_BIN := $(BUILD_DIR)/bin/tooling-updater

# Stamp file prevents redundant setup-env re-checks within a single make invocation
ENV_STAMP := $(BUILD_DIR)/.env-stamp

define mamba_env_exists
	$(MICROMAMBA) env list --json 2>/dev/null | grep -q '/$(MAMBA_ENV)"'
endef
