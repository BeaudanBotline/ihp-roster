# Helpers Runtime Decoupling Handoff

## Workstream status

- Coordinator Beads epic: `coordinator-6ye`
- Status: active
- Starting checkout context: local checkout on `weaver/roster-live-fragments`
- Last confirmed repo commit at planning time: `4921bfe`

## What has been done

- Audited the vendored IHP `helpers.js` behavior and the app's current usage.
- Confirmed the duplicate-submit bug root cause: HTMX form submits and the document-level IHP submit listener both handled the same event.
- Confirmed the current app-side mitigation in `static/app.js` is a targeted boundary, not a framework patch.
- Created a dedicated Beads migration lane for fully retiring `helpers.js`:
  - `coordinator-6ye.2` decide post-helpers transport boundary and fallback policy
  - `coordinator-6ye.1` replace `.js-delete` with an explicit app-local destructive action pattern
  - `coordinator-6ye.3` migrate remaining required UI helpers out of `helpers.js`
  - `coordinator-6ye.4` rehome plain forms onto the chosen submission model
  - `coordinator-6ye.5` remove `helpers.js` from layout/build and verify regressions
- Recorded the settled migration policy in repo docs:
  - HTMX remains for partial/in-place workflows
  - admin/config, exports, profile, login, and invitation/bootstrap forms should default to native full-page submits
  - destructive actions should be explicit `POST + _method=DELETE` forms
  - the date/datetime picker enhancement should be kept in app-local JS
  - TurboLinks is decoupled from form transport and may remain temporarily only for navigation/lifecycle behavior
- Implemented `coordinator-6ye.1`:
  - logout in `Web/View/Layout.hs` is now an explicit delete form
  - leave delete in `Web/View/LeaveRequests/Index.hs` is now an explicit delete form that still uses HTMX for in-place updates
  - timesheet delete in `Web/View/Timesheets/Index.hs` is now an explicit delete form that still uses HTMX for in-place updates
  - there are no remaining runtime `.js-delete` consumers under `Web/`, `Application/`, or `static/`
- Added regression coverage:
  - `Test/Controller/LeaveRequestsSpec.hs` now asserts the authenticated leave page renders explicit delete forms and the logout delete form, with no `js-delete` markup
  - `Test/Controller/TimesheetsSpec.hs` now asserts timesheet cards render explicit delete forms with hidden `_method=DELETE`, with no `js-delete` markup
- Implemented `coordinator-6ye.3`:
  - added app-local flatpickr initialization in `static/app.js`
  - the app-local picker init runs on `DOMContentLoaded`, `turbolinks:load`, and HTMX swap events so dynamically inserted leave dialogs receive the same enhancement as full-page forms
  - the app-local picker init is idempotent and detects pre-existing flatpickr instances, which lets it coexist safely with `helpers.js` until the final removal slice
- Confirmed runtime audit results for the smaller `helpers.js` helpers:
  - no app-runtime consumers remain for `.js-back`
  - no app-runtime consumers remain for `[data-toggle]`
  - no app-runtime consumers remain for `data-preview` file previews
  - no app-runtime consumers remain for `.time-ago`, `.date-time`, `.date`, or `.time` formatting helpers
- Added a Playwright regression to prove HTMX-inserted leave-request date inputs still get flatpickr after the app-local initialization path runs

## Current architectural assessment

- Short-term: keep the centralized HTMX submit isolation currently in `static/app.js`
- Long-term: remove `helpers.js` entirely once replacement work is complete
- The policy and first implementation slice are now aligned:
  - HTMX for in-place partial workflows
  - native browser submits for low-frequency full-page forms
  - explicit destructive-action forms instead of `.js-delete`
  - app-local date picker initialization should be the retained non-transport helper

## Settled technical decisions

1. TurboLinks
   - Keep it separate from form transport.
   - It may remain temporarily for navigation/lifecycle behavior, but it should not own form submission.
2. Plain full-page forms
   - Admin/config, exports, profile, login, and invitation/bootstrap forms are acceptable as native full-page submits by default.
3. Destructive actions
   - Replace `.js-delete` with explicit app-owned forms using `POST` plus hidden `_method=DELETE`.
   - Do not introduce another broad delete-link shim.
4. UI helpers
   - Keep the date/datetime picker enhancement.
   - Drop unused smaller helpers unless implementation finds a real dependency.

## Branching note

This lane currently points at the same checkout as `coordinator-ck3` only because that is where the current app state exists.

Before implementation begins, confirm whether to:

- stack directly on `weaver/roster-live-fragments`, or
- cut a fresh follow-on branch after `coordinator-ck3.5` lands

Do not assume that decision has already been made.

## Immediate next action

Start `coordinator-6ye.4` by applying the chosen post-helpers form policy to the remaining non-HTMX forms. The intended default remains native full-page submits for low-frequency pages, with only the clearly interactive roster flows promoted to HTMX if needed.

## Verification

Ran in this pass:

- `bash ./bin/in-env format`
  - passed
- `bash ./bin/in-env typecheck`
  - passed
- `bash ./bin/in-env test --match LeaveRequestsController`
  - passed with `21 examples, 0 failures`
- `bash ./bin/in-env test --match TimesheetsController`
  - passed with `18 examples, 0 failures`
- `bash ./bin/in-env e2e e2e/live-fragment-submit-regressions.spec.ts`
  - passed with `3 passed`
