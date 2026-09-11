---
name: tracker-setup
description: Use when a project's issue tracker or board is missing fields needed to prioritize work, or when setting one up from scratch. Self-contained — no other file or skill required.
---

# Tracker Setup

Sets up the structural fields an issue tracker needs so that priority,
readiness, and scheduling questions are answerable from the tracker itself
rather than re-derived from memory or a scattered set of documents each
time someone asks "what's next." Works with any tracker that supports
custom fields on issues/tickets (GitHub Projects, Jira, Linear, and
similar) — adapt the exact mechanics to whichever one is in use.

## Why fields, not documents

A separate roadmap document (a markdown table, a spreadsheet) drifts from
reality the moment someone updates an issue without also updating the
document. A tracker field attached to the issue itself cannot drift from
"the issue" because it _is_ part of the issue. Prefer adding a field over
adding a document every time both would answer the same question.

## The minimal field set

Six fields cover nearly every prioritization and scheduling question.
Add a field only when a real, recurring question needs it — an unused
field just adds upkeep nobody does, which then quietly turns it into a
value nobody trusts.

1. **Status** — use the canonical readiness states `Backlog`, `Spec Needed`,
   `Spec Ready`, `In Progress`, `Blocked-Needs-Human`, and `Done`. Keeping
   `Spec Needed` separate from `Spec Ready` makes "what can I start right
   now" answerable without reopening every issue.
2. **Priority** — an ordinal scale (e.g. P0–P4, or Critical/High/
   Medium/Low). Ordinal, not a free-text field — free text can't be
   sorted or filtered on reliably.
3. **Target release / milestone** — which shipping boundary this belongs
   to, including an explicit "unscheduled" value for backlog items that
   aren't committed to any release yet. Without this, "unscheduled
   someday" work and "committed for the next release" work look
   identical in a flat list.
4. **Area / component** — a short, stable categorization (subsystem,
   team, or product area). Lets someone filter to "everything touching
   X" without full-text search, and helps spot which area is accumulating
   unaddressed work.
5. **Effort or size** — a rough t-shirt size (XS–XL) or points. Doesn't
   need to be accurate to the hour to be useful; it only needs to
   distinguish "an afternoon" from "a multi-week effort" so scheduling
   conversations have a shared unit.
6. **Parent/child or epic linkage** — whatever the tracker calls it
   (sub-issues, epic links, a "blocks/blocked by" relation). Needed to
   answer "is this part of something bigger" and "does finishing this
   unblock anything else" without manually cross-referencing issue
   bodies.

Everything else (Risk, custom labels, a "requires design review" flag) is
optional — add it only when a real recurring question needs it, following
the same rule as above.

## What this does not cover

Setting up _views_ that filter/sort/group by these fields for fast visual
scanning, and the actual step-by-step logic for _picking_ the next task
from what these fields say, are both separate concerns from setting the
fields up in the first place — each has its own focused approach; this
skill's job ends at "the fields exist and are populated."

## Populating existing issues

When adding a field to a tracker that already has issues in it, backfill
existing items in priority order — don't leave old issues with the field
blank indefinitely, since a blank field is indistinguishable from "checked
and intentionally unset" to anyone filtering on it later. If backfilling
everything at once isn't practical, at minimum backfill anything already
in progress or committed to a near-term release before adding any new
issue without the field set.

## Mechanics note (GitHub Projects v2 example)

If the tracker is a GitHub Project (v2), fields and their options can be
created and edited via `gh project field-create` / the GraphQL API
(`createProjectV2Field`). Two real constraints, confirmed by trying them
directly:

- Editing a single-select field's _option list_ (not just adding items to
  it) can rewrite every existing item's stored value for that field
  project-wide. Before editing options on a field with any real data in
  it, dump the field's current values first so a mistake is recoverable.
- Field creation and item edits are scriptable; _view_ configuration
  (which fields are visible, sort order, grouping) largely is not. A view
  can typically be created and given a filter string through the API, but
  its sort order and grouping usually still need one manual pass through
  the UI afterward — confirm this against the tracker actually in use
  rather than assuming either way.
