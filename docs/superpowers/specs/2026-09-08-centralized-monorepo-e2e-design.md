# Centralized Monorepo E2E Design

## Goal

Add an isolated end-to-end scenario that proves centralized quality delivery
works for a generated `languages=all` consumer without relying on a pre-existing
central repository.

## Scope

The scenario is an opt-in preset of the existing repository-creation test
workflow. It creates two uniquely named temporary repositories owned by the
configured E2E owner: a central workflow seed and a generated consumer. It
does not migrate existing repositories or change normal embedded delivery.

## Architecture and data flow

1. The test job creates the central repository through the GitHub API, uploads
   the contents of `templates/centralized-actions-workflows`, commits them, and
   records the resulting full commit SHA.
2. The test job dispatches the existing API repository-creation workflow with
   `languages=all`, `delivery_mode=centralized`, and the central repository plus
   captured SHA. The consumer is therefore created through the same production
   path as an ordinary centralized repository.
3. The test job validates both repositories through GitHub API calls, including
   seed workflow shape, consumer caller/ref, profile metadata, monorepo
   capabilities, repository settings, ruleset checks, and permissions.
4. The test job dispatches and polls the consumer quality workflow and fails if
   it does not complete successfully.
5. A final cleanup job deletes both repositories only when requested or when
   the scenario fails. With `cleanup_after_test=false` after success, both
   repositories remain available and the summary prints deterministic `gh repo
   delete OWNER/REPO --yes` commands.

The existing allowlisted E2E cleanup token and repository-name validation remain
the only deletion path. Cleanup is idempotent: missing repositories are treated
as already removed, while unexpected API errors fail the cleanup job.

## Contracts

The central repository must contain the seed README, reusable quality workflow,
and setup actions, and its workflow files must expose `workflow_call` without
push, pull-request, or workflow-dispatch triggers. The consumer must contain its
own setup/configuration files and caller workflow, must not contain embedded
quality implementation workflows/actions, and must record the exact central
repository and 40-character commit SHA in its validated bootstrap profile.

The consumer assertions must cover all normalized monorepo language metadata,
quality capability configuration, repository settings, active strict-main
ruleset targeting the default branch, required `quality` and signed-off checks,
and successful execution of the generated quality workflow.

## Testing and documentation

Deterministic shell contract tests will verify the preset inputs, central-seed
restrictions, immutable-ref propagation, dual-repository cleanup wiring, and
manual cleanup documentation without contacting GitHub. The live workflow
remains the authoritative E2E test. A Make target will expose the scenario and
the workflow summary will document cleanup commands for preserved repositories.

## Error handling

Every created repository name is written to job outputs before subsequent
steps. Failure cleanup receives both names and attempts each independently,
reporting the repository and API response for failures. Central commit or
consumer creation failure stops validation and still invokes cleanup according
to the existing failure policy.
