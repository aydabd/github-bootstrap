---
name: backlog-breakdown
description: Use when an issue-tracker item lacks a clear requirement, acceptance criteria, dependencies, test layer, or exact verification command.
---

# GitHub Issue Breakdown

Turns a backlog item that is just a title and a paragraph into a complete
issue work contract. In this repository the tracker is GitHub, but the
breakdown is deliberately tracker-shaped rather than GitHub-API-shaped. The
issue should be executable by a human or agent
without creating a second planning system in the repository.

## When an item needs this

An item needs breakdown, not implementation, when any of these is true:

- The GitHub issue does not state the requirement, acceptance criteria, or
  verification.
- The item is large enough that "just start coding" would require making
  several non-obvious design calls along the way, each of which deserves
  to be decided once, deliberately, and recorded — not decided silently
  mid-implementation where nobody else can see the reasoning or question
  it before it ships.

An item does _not_ need this skill if a task list already exists and
simply hasn't been started yet — that's a scheduling question, not a
breakdown question.

## What a good breakdown contains

Keep these parts in the issue:

1. **Why and what.** The problem being solved, in enough detail that
   someone unfamiliar with the backstory understands why this item
   exists at all — not just what to build. Include acceptance criteria
   as a short, numbered list of concrete, checkable conditions ("an
   unauthenticated request is rejected," not "the endpoint is secure") —
   numbered so later work can reference exactly which criterion it
   satisfies.
2. **Design decisions.** For each non-trivial choice, record: what was
   decided, and what alternatives were considered and rejected, with the
   real reason each alternative was rejected (a technical limitation
   discovered by checking, an explicit preference the requester stated,
   a cost tradeoff someone accepted knowingly) — not a vague "seemed
   better." A decision worth writing down is one that a later reader
   might otherwise want to silently redo or question; recording the
   rejected alternatives up front is what stops that from happening
   twice. If a decision gets revisited later because something assumed
   at design time turned out to be false, record _that_ too, in place,
   rather than quietly editing over the original reasoning — the history
   of why something changed is often as valuable as the current answer.
3. **An ordered checklist.** Each item should be sized so it can be:
   - implemented and validated on its own, ideally as one reviewable
     unit of work (e.g., one pull request);
   - validated by a concrete, stated command or observation — not
     "should work," but the literal command to run or the literal
     behavior to observe, so completion isn't a matter of opinion;
   - checked off decisively once done, so the whole list's overall
     progress (n of m complete) is visible to anyone glancing at it,
     including a prioritization pass that's deciding what to work on
     next.

   Order tasks so each one either doesn't depend on a later one, or
   explicitly says which earlier task it depends on. Tasks in this list
   are sequential by default — later tasks are allowed to assume earlier
   ones already landed — unless a task explicitly says it's independent
   and safe to do alongside another.

## Sizing tasks correctly

Too large: a task that can't be validated except by also finishing
several _other_ tasks first is really multiple tasks pretending to be
one — split it.

Too small: a task that isn't independently useful or mergeable on its own
(e.g., "add a type definition" with nothing yet using it) usually belongs
folded into the task that actually needs it, not left as its own
checkbox — a task list of pure micro-steps is harder to track progress
against than one of meaningfully-sized, independently-shippable steps.

## Recording where the breakdown lives

Use the issue as the predictable location. Use linked sub-issues only when
work needs independent ownership or releases; do not duplicate the same
checklist in `docs/specs/**`.

## Keeping it honest as work proceeds

A breakdown is a living issue until the item is done: tick checklist items
off as they land, link PRs and test evidence, and update the issue when
reality diverges. Durable product, security, architecture, and user-facing
decisions still belong in repository docs, but implementation planning stays
in GitHub.
