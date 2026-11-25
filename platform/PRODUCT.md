# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Participants are teenagers (13 to 18) building one hardware project for Hack Club Fallen. They submit designs for
review to get parts funded.

Design reviewers read a submission, judge its hours and parts, and propose a decision: approve, return for changes,
or reject for good.

A few admins sign off each proposed decision before it reaches the participant, at a desktop, working through a
batch. Signing off applies the decision, changes hours and XP, and sends funding to the participant's HCB card.

## Product Purpose

Fallen funds teenagers' hardware projects and takes the ones who qualify to Shenzhen. Funding is quality based and
qualification is hour based (see `program/the-plan.md`, whose numbers are not settled).

Sign-off is the last check before money and hours move. Success is an admin who can confirm or correct a reviewer's
call quickly and confidently, catch copied designs and inflated hours, and leave a clear record of what they changed.

## Operating Context

- Reviews happen on `/review`; held decisions wait on `/admin/sign-offs` until an admin signs them off, sends them
  back to the queue, or edits them on the review page first.
- A copy check compares a submission's design files against public repositories. A match is a reason for a person
  to compare the two designs, never a decision on its own.
- The sign-off experience and the copy checker live in a private repository mounted at `platform/vendor/desk`.
  Without it, the app runs and falls back to the public sign-off list.

## Capabilities and Constraints

- Rails 8.1, Inertia, Svelte 5, Tailwind 4. Motion (springs) is the incumbent animation library.
- Nothing in a request waits on the network; the copy check runs in a background job.
- Every page has a query budget and lists are paginated.
- A copy check match blocks approval until an admin confirms they compared the designs.

## Brand Commitments

- "Hack Club", always written that way.
- Copy is short and plain: no em or en dashes, nothing that reads as written by AI.
- Sign-off should feel as good to use as a polished consumer app (the user named the Family wallet app as the
  inspiration), while staying a working tool.

## Evidence on Hand

Real submissions, journals, bills of materials, reviewer proposals and copy check results in the app's database. No
testimonials or usage numbers exist; none may be invented.

## Product Principles

- Money and hours move only on a person's deliberate call.
- Show the evidence beside the decision, not behind a click.
- A copy match slows you down; it never decides for you.
- Fast for the expert who signs off dozens in a row.
