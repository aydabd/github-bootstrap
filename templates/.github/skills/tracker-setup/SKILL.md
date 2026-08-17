---
name: tracker-setup
description: Use when a GitHub Project lacks the fields needed to prioritize and schedule work.
---

# Tracker Setup

Configure only when explicitly requested. Prefer the smallest useful field
set: Status (`Needs plan`, `Ready`, `In progress`, `Blocked`, `Done`),
Priority, Target release, Area, Size, and Parent or dependency. Preserve
existing field values before changing single-select options, and backfill
active or release-committed issues before relying on new filters.

Verify the project and repository identity, permissions, field IDs, and option
names through the GitHub API before applying changes. Report unsupported plan
features clearly; do not silently replace a requested field with a label.
