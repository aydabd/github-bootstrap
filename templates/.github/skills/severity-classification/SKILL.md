---
name: severity-classification
description: Classify review findings into blocking, non-blocking, or note with consistent merge-risk rules.
license: MIT
---

## Severity rules

`blocking` means the PR should not merge as-is:

- security vulnerability
- data loss or corruption risk
- broken public contract
- failing build/test caused by PR
- production outage risk
- incorrect critical business logic
- migration rollback hazard

`non_blocking` means it should be fixed soon but can merge if accepted by owner:

- missing useful test
- unclear naming affecting maintainability
- minor performance issue
- incomplete docs for internal behavior

`note` means useful context, not a requested change.

Do not inflate severity. If uncertain, use `non_blocking` or omit the finding.
