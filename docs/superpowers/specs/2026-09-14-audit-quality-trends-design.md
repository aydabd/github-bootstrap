# Phase 5 audit quality trends design

## Goal

Implement the final phase of Issue #218: deterministic quality metrics and
qualified trend output for completed issue and pull-request outcomes. The
implementation consumes sanitized evidence records produced by the existing
Phase 2 provenance collector, Phase 3 GitHub verifier, and Phase 4 bypass
governance layer.

## Scope

The metric engine will accept an explicit collection of completed audit
records. It will validate the records at the input boundary, select comparable
cohorts, calculate raw measurements and component results, and emit one safe,
deterministically serialized JSON document. Cohort fields are work type, risk,
and approximate effort; those fields are frozen when work starts and are never
reclassified to improve a result.

The output will contain eligibility, cohort membership, raw measurements, and
components for compliance, correctness, review quality, delivery efficiency,
and process improvement. A trend comparison is available only when five
eligible prior outcomes exist. Missing required evidence produces `INVALID`
rather than a zero or a favorable score. Repeated CI failures, bypasses,
reverts, reopened issues, stale approvals, unresolved review threads, and
post-first-CI pushes remain visible in the raw components.

People and models will not be scored. Provider-attested provenance may be
reported as an input dimension, while self-declared identity remains metadata.
The engine will not retrieve GitHub data, inspect credentials, read raw logs,
or reconstruct missing evidence. The Phase 3 sanitized record is the only
evidence boundary.

## Components

1. **Input validator** accepts only the allowlisted sanitized record shape,
   verifies issue/PR identity and required evidence status, rejects sensitive
   values without echoing them, and returns fixed failure codes.
2. **Cohort selector** filters completed records by frozen work type, risk, and
   effort, orders them by the declared completion sequence, and selects the
   previous five eligible outcomes. It rejects duplicate identities and
   ambiguous cohort fields.
3. **Metric calculator** derives raw counts and ratios from evidence already
   present in the records. It preserves invalid and unavailable states instead
   of inventing values, and applies the manifest's anti-gaming rules.
4. **Trend serializer** emits fixed field and array order, stable numeric
   formatting, the cohort qualification state, raw components, and the final
   componentized result. It never includes rejected input, free-form text, or
   raw evidence.

The public entrypoint will be a small local command with explicit input and
output paths. Temporary input or intermediate evidence is deleted on success,
rejection, failure, and interruption; cleanup is idempotent and cleanup
failure causes a fixed failure result. No GitHub workflow or Phase 3 adapter
will be modified unless a contract test proves that an existing entrypoint
must invoke the metric engine.

## Result rules

The result will use the manifest's `PASS`, `FAIL`, and `SKIP` values. A
qualified cohort with complete evidence can produce a componentized trend.
An incomplete or unsafe record is `INVALID` and exits non-zero. Fewer than
five comparable eligible outcomes produces a deterministic insufficient-cohort
result without publishing a trend. Optional diagnostics may be `SKIP` only
when explicitly inapplicable; required compliance evidence never becomes an
optional skip.

Every output includes raw measurements alongside component outcomes and the
reason for qualification or invalidity. Scores will be bounded and derived
only from declared components. No aggregate score is emitted without its
components and raw values.

## Testing

Tests will be written first against deterministic synthetic records and will
assert parsed structures, exact ordering, byte stability, exit behavior, and
privacy rejection. Coverage will include:

- five eligible records and a qualified trend;
- zero through four records and mismatched cohort fields;
- missing, invalid, stale, conflicting, and unavailable evidence;
- repeated CI failures, reruns, pushes after first CI, bypasses, reverts,
  reopened issues, review findings, stale approvals, and unresolved threads;
- invalid and provider-attested provenance handling;
- anti-gaming attempts such as dropping tests or comments;
- secret, token, prompt, reasoning, path, email, and raw-log rejection;
- deterministic field/array ordering and repeated serialization;
- transient evidence cleanup on success, rejection, failure, and interruption;
- source/generated template parity and fixed safe failures.

Validation will run the focused metric tests, relevant audit contracts, the
full deterministic contract suite, and `LINT_MODE=check make quality`.

## Boundaries and delivery

This phase does not create or manage a GitHub Project, retrieve GitHub API
data, alter the Phase 1 schema, change Phase 2–4 behavior, add live scoring
for people or models, or implement browser E2E. It will use a new worktree
from `origin/main`, a separate signed-off pull request linked to Issue #218,
and will leave PR #217 and merged PRs #220, #222, #227, and #229 unchanged.
