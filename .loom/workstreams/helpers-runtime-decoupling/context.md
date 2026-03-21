# Helpers Runtime Decoupling Context

## Workstream identity

- Coordinator Beads epic: `coordinator-6ye`
- Workstream id: `ihp-roster-helpers-runtime-decoupling`
- Project: `ihp-roster`
- Base branch: `roster`
- Starting checkout context: `weaver/roster-live-fragments`
- Last confirmed repo commit at planning time: `4921bfe`

## Objective

Retire the app's dependency on IHP `helpers.js` and converge on one coherent app-local frontend runtime.

That means:

1. replace the app-visible `helpers.js` behaviors still in use
2. deliberately drop the legacy helpers that are unused or no longer desirable
3. stop relying on document-level IHP form interception as a transport layer
4. keep HTMX/live fragments and explicit app JS as the primary client model

## Why this exists

The current live-fragment work exposed a transport conflict:

- IHP `helpers.js` installs a document-level submit listener for all forms
- HTMX handles submits on `hx-*` forms
- a single click on an HTMX form can therefore produce two mutations unless the event is isolated before it bubbles to the IHP handler

The repo currently works around that in `static/app.js` by stopping submit propagation for HTMX forms. That is a valid short-term boundary, but the long-term direction is to remove the mixed ownership entirely.

## Confirmed current dependencies on helpers.js

- `.js-delete` destructive link shim is still used for:
  - logout in `Web/View/Layout.hs`
  - leave delete in `Web/View/LeaveRequests/Index.hs`
  - timesheet delete in `Web/View/Timesheets/Index.hs`
- plain non-HTMX forms still receive IHP AJAX + TurboLinks behavior when `helpers.js` is loaded, notably on:
  - `Web/View/Admin/Index.hs`
  - `Web/View/Exports/Index.hs`
  - `Web/View/Profiles/Edit.hs`
  - `Web/View/Sessions/New.hs`
  - `Web/View/Users/New.hs`
  - some roster forms in `Web/View/RosterWeeks/Show.hs`
- flatpickr/date enhancement currently comes from `helpers.js`

Confirmed likely-unused helpers in app code:

- `.js-back`
- `[data-toggle]`
- `data-preview` file-preview helper
- `.time-ago`, `.date-time`, `.date`, `.time` formatting helpers

## Settled migration decisions

1. Non-HTMX forms after `helpers.js`
   - Default to native browser submits for low-frequency full-page workflows.
   - Do not replace IHP's document-wide AJAX submit interception with another app-wide transport shim.
2. Replacement for `.js-delete`
   - Use explicit destructive-action forms with `POST` plus hidden `_method=DELETE`.
   - HTMX belongs only on surfaces that already need in-place updates.
3. TurboLinks
   - Keep it separate from form transport.
   - If retained during this migration, it remains only a page-navigation/lifecycle concern.
4. UI helpers to keep
   - Keep date/datetime picker enhancement.
   - Drop unused smaller helpers unless later code proves they still matter.

## Read order for the next implementation pass

1. `repos/ihp-roster/AGENTS.md`
2. `repos/ihp-roster/.loom/workstreams/helpers-runtime-decoupling/handoff.md`
3. `repos/ihp-roster/Web/View/Layout.hs`
4. `repos/ihp-roster/static/app.js`
5. `repos/ihp-roster/IHP/ihp/data/static/helpers.js`
6. the Beads epic `coordinator-6ye` and its child tasks

## Suggested migration order

1. record the settled transport/runtime policy in repo docs
2. replace `.js-delete`
3. move any still-needed UI helpers into app-local JS
4. rehome remaining plain forms onto the chosen submission model
5. remove `helpers.js` from layout/build and verify regressions
