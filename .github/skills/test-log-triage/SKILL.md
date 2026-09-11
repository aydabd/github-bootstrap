---
name: test-log-triage
description: Use when a test, lint, E2E, or make command produces failures or long reports.
---

# Test Log Triage

The canonical implementation is
`templates/.github/skills/test-log-triage/SKILL.md`. Read it before changing
code in response to a test result. Classify the result as product defect,
test defect, fixture/state pollution, infrastructure failure, or genuine
flake. Use machine-readable JUnit/JSON reports first and record the command,
artifact, counts, classification, first actionable error, and next command.

Never make a required suite green with retries, skips, `expect(true)`, or a
conditional pass.
