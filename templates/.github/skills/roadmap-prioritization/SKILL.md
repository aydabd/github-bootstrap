---
name: roadmap-prioritization
description: Use when choosing the next task(s) to work on from a backlog, deciding whether picked tasks can run in parallel or must run in sequence, or reprioritizing/documenting a roadmap. Self-contained — no other file or skill required.
---

# Roadmap Prioritization

Use this before picking the next implementation task, starting two tasks
side by side, or reordering a backlog. Works with any issue tracker (GitHub
Issues, a project board, Jira, Linear, a plain markdown backlog) — adapt the
field names below to whatever the actual tracker calls them.

## Step 1 — Gather live state

List the open candidates and their current tracker fields: priority,
status, target release/milestone, labels, and any parent/child or
blocks/blocked-by links. Treat the tracker (not a separate roadmap
document) as authoritative for current status — a document can describe
_why_ a decision was made, but a live tracker field wins on _what state
something is in right now_.

If a document's stated priority or status disagrees with the tracker,
do not silently pick one. Say so explicitly in your output (Step 5) — the
tracker is authoritative for live state, but the document's stated
rationale can still be correct even if the tracker's field is just stale.

## Step 2 — Readiness check, per candidate

For each candidate, work out which bucket it's actually in:

- **Incomplete issue contract** — the GitHub issue does not state the
  requirement, acceptance criteria, dependencies, test layer, and exact
  verification. Improve the issue before implementation; do not create a
  repository planning folder by default.
- **Planned, not started** — the issue contract is complete but no checklist
  item is complete.
- **In progress** — some but not all of its sub-tasks are complete.
- **Done** — nothing left; should already be closed.

Count completed vs. remaining issue checklist items and linked PRs. That one
number is frequently the deciding signal between two candidates that
otherwise look equally urgent: an item with 6 of 8 steps already done is
almost always worth finishing before starting a fresh item at the same
priority. Required checks are also part of readiness; a failing required suite
blocks new feature selection unless the issue records an explicit release
exception.

## Step 3 — Priority tiers

Rank candidates in this order unless someone with the authority to set
scope gives an explicit, stronger release decision that overrides it:

1. Active production incidents, and security or privacy exposures.
2. Structural fixes that stop the same class of bug or exception from
   recurring (source-of-truth refactors, closing a whole category of gap
   rather than patching one instance of it).
3. Tracker/process hygiene that is _currently_ blocking reliable planning
   (e.g., work that exists but isn't tracked anywhere, or priorities that
   have visibly drifted from reality).
4. Committed release blockers — whatever must ship for the next
   committed release to go out.
5. Flaky or failing tests that weaken confidence in release evidence.
6. Maintainability and cleanup work.
7. New features beyond what's already committed to the next release.

Within a tier, prefer the candidate that unlocks multiple other blocked
items over one that's isolated — all else equal, removing a bottleneck is
worth more than an equally-sized independent task. Never let tier-6/7 work
jump ahead of tier-1/2 items unless someone has explicitly changed release
scope to allow it; don't infer that permission from silence.

## Step 4 — Decide parallel vs. sequential

Once two or more candidates sit at the same priority tier, decide whether
to run them side by side or one after another.

Two tasks are safe to run **in parallel** only if _both_ of these hold:

1. **No dependency between them** — neither is a parent/child of the
   other, neither is listed as blocking or blocked-by the other, and
   neither's design assumes the other has already landed.
2. **No file/module overlap** — check the actual set of files or
   modules each would touch (from its own breakdown, or its stated scope
   if no breakdown exists yet), not just which product area it's filed
   under. Two tasks in the "same area" can still be parallel-safe if their
   real diffs don't overlap, and two tasks in "different areas" can still
   collide if they'd both touch a shared file (a shared config, a shared
   schema migration, a shared lockfile).

If both hold, they can proceed in separate branches/workspaces at the same
time. If either fails, treat them as sequential: do the higher-tier one
first, then re-evaluate the second once the first has actually landed —
its own scope or the files it touches may have shifted underneath it.

One case is sequential by definition, not by the two checks above: the
individual steps _inside_ one candidate's own breakdown (its own "task 1,
task 2, task 3…"). Those are ordered because each step is scoped to build
on the previous step's actual outcome, not because of a file collision —
never parallelize within a single item's own breakdown, even when nothing
else seems to block it.

## Step 5 — Output

State plainly:

- The next recommended task(s), each tagged with its readiness bucket
  (Step 2) and priority tier (Step 3).
- Whether the recommended set should run in parallel or in sequence, and
  which of Step 4's two checks drove that call.
- Any tracker/document mismatch found in Step 1.
- What was actually checked to reach this conclusion (which sources, and
  whether state was read live or assumed from memory) — so the
  recommendation can be re-verified rather than taken on faith.

## Applying the result

Update whichever system is the actual live source of truth for status and
priority — a tracker field, a label, a board column — rather than a
separate document that can silently drift out of sync with it. If the
reasoning behind a reorder is non-obvious, or overrides this skill's
default tier order, leave a short note recording _why_ on the item itself,
so a later reader (human or agent) doesn't have to re-derive the same
reasoning from scratch.
