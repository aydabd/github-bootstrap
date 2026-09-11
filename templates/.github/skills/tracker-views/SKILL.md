---
name: tracker-views
description: Use when a project's issue tracker needs discovery views so "what's ready to work on right now" is answerable at a glance, by a human looking at a board or an agent querying an API. Self-contained — no other file or skill required.
---

# Tracker Views

Sets up saved views on an issue tracker so "what can I start right now,
ranked correctly" is answerable by looking, not by re-deriving it from
scratch each time. A tracker with the right fields (priority, status,
etc.) but no purpose-built view still forces every reader — human or
agent — into the same manual filtering-and-cross-referencing exercise
every single time. The views are what turn "the data exists somewhere in
here" into "glance and go."

## The three views worth having

Every tracker with more than a handful of items benefits from these
three, at minimum:

1. **Ready to work.** Filtered to `Spec Ready` and `In Progress`, sorted by
   priority. This is the single most
   valuable view: it answers "what should I pick up next" directly,
   without anyone needing to cross-reference readiness against priority
   by hand. If the tracker's fields don't yet distinguish `Spec Needed`
   from `Spec Ready`, fix that first — a filter can't select a
   distinction the data doesn't carry.
2. **By release / milestone.** Grouped by target release (including an
   "unscheduled" bucket), for release-planning conversations — "what's
   actually committed for the next release" versus "what's just sitting
   in the backlog."
3. **Top-level / epics only.** Filtered to items with no parent (or
   explicitly tagged as an epic/initiative), so the overall shape of the
   roadmap is visible without every implementation task cluttering the
   view. Useful for a "where are we, broadly" conversation that doesn't
   need task-level detail.

Add more only when a real, recurring question isn't answered by these
three — a "Blocked items" view, a "my assigned items" view, and similar
are legitimate but optional; don't build them speculatively.

## Building the filter correctly

State the filter in terms of the actual field values the tracker stores,
not an approximation. If "ready to implement" and "in progress" are both
legitimate "ready to work" states, the filter needs to match _both_ — a
filter matching only one silently hides half of what should be visible,
and a hidden gap in a filter reads identically to "there's nothing to
do," which is a worse failure mode than an obviously broken view.

## Verify the filter actually matches — don't trust it blindly

A saved filter can be syntactically accepted by the tracker and still
match nothing, or match the wrong set, because of a subtle mismatch
between the filter's field-name/value syntax and what the tracker
actually expects (quoting rules, hyphenation, case sensitivity all vary
by tracker). Before trusting a new or edited view:

1. Compute, independently, which items _should_ match (list all items and
   filter them yourself against the same criteria, in a script or by
   hand for a small tracker).
2. Compare that against what the view actually shows or returns.
3. If they disagree, don't assume the view will "settle" — try a small,
   deliberate change to the filter syntax, or delete and recreate the
   view outright, then re-verify. A silently-empty or silently-wrong view
   is worse than no view, because it looks authoritative while being
   wrong.

## Mechanics note

Most modern trackers expose enough API surface to create a view and set
its filter and visible columns programmatically. Sort order and grouping
are less consistently exposed — treat those as something to verify
support for on the specific tracker in use, and be ready to ask a human
to set them once through the UI if the API genuinely doesn't support it,
rather than silently leaving a view half-configured without saying so.
