# Timesheets And Leave Live Fragments Handoff

## Workstream status

- Coordinator Beads epic: `coordinator-ck3`
- Status: in progress
- Starting branch context: local checkout on `weaver/roster-live-fragments`

Completed in this pass:

- `coordinator-ck3.1` implemented: the shared live-update runtime now supports `LeaveRequestsScope` and `TimesheetWeekScope` alongside `RosterWeekScope`, plus corresponding fragment-key constructors for leave content and timesheet day sections.
- `static/app.js` now derives scope keys by scope kind instead of assuming every live surface has a `weekOffset`, and it includes dormant leave/timesheet adapters so later page work can wire owners without changing the transport core again.
- `Web/Controller/LiveUpdates.hs` authorization now recognizes leave-list venue scopes and timesheet week scopes explicitly.
- Added `Test/LiveUpdateSpec.hs` JSON roundtrip coverage for the shared scope/fragment types.
- `coordinator-ck3.2` implemented: leave approval/denial no longer relies on `roster_weeks.updatedAt` touches for roster freshness.
- `Web/Controller/LeaveRequests.hs` now computes affected week offsets and reuses the existing roster live-update helpers to broadcast `RosterContentFragment` and `RosterStaffPanelFragment` invalidations for each affected week scope.
- `Application/Helper/Controller.hs` no longer carries the stale `triggerRosterConflictRecomputeForLeave` helper.
- `Test/Controller/LeaveRequestsSpec.hs` now asserts live-update version increments on the correct `RosterWeekScope` values and locks in the deny-after-approved path as well.
- `coordinator-ck3.3` implemented: the leave page is now a live-fragment consumer with a venue-scoped owner shell, a canonical leave-content fragment endpoint, and mutation broadcasts for create/approve/deny/delete.
- `Web/View/LeaveRequests/Index.hs` now mounts the leave page as `data-live-update-feature="leave-requests"`, exposes `ShowLeaveRequestsContentFragmentAction` as the canonical fragment refetch URL, and uses HTMX mutation wiring for review/delete actions so the acting tab updates immediately.
- `Web/Controller/LeaveRequests.hs` now:
  - serves `ShowLeaveRequestsContentFragmentAction`
  - broadcasts `LeaveRequestsScope` invalidations after create/approve/deny/delete commit
  - returns immediate actor fragment/toast responses for HTMX leave mutations
  - closes the leave-request dialog out-of-band after a successful HTMX create
- The leave fragment renderer now takes the viewer's staff id explicitly instead of reaching into `currentUserOrNothing` during fragment-only renders. That avoids the frozen-context crash on fragment endpoints and keeps delete-button visibility consistent for workers viewing their own requests.
- `static/app.js` now gives the leave adapter a real resync path by refetching `#leave-requests-content` when a leave-scope subscribe ack reports version drift.
- `Test/Controller/LeaveRequestsSpec.hs` now covers:
  - leave-page shell subscription metadata
  - fragment visibility scoping for manager vs worker viewers
  - HTMX actor responses for create
  - leave-scope version bumps for create/review/delete
- `coordinator-ck3.4` implemented: the timesheet week page now participates in the shared live-update runtime.
- `Web/Types.hs` adds `ShowTimesheetDaySectionFragmentAction`, and `Web/Controller/Timesheets.hs` now:
  - serves canonical day-section fragment refetches
  - broadcasts `TimesheetWeekScope` invalidations for create/update/delete/approve/unapprove
  - returns actor-side day-section OOB refreshes plus toast/dialog updates for HTMX flows
- `Web/View/Timesheets/Index.hs` now mounts the page shell as `data-live-update-feature="timesheets"`, marks each day section with its canonical refetch URL, and converts approve/unapprove/delete controls to HTMX paths so actor and passive-viewer updates stay aligned.
- `static/app.js` now gives the timesheets adapter a real scope resync path by refetching each mounted day section.
- Fixed the duplicate-submit bug affecting leave and timesheet create flows. Root cause: IHP `helpers.js` installs a document-level submit handler for every form, so HTMX overlay forms were being submitted twice unless the submit event was isolated before it reached the IHP helper layer.
- Added regression coverage for that duplicate-submit bug:
  - controller checks lock in HTMX form markup for leave and timesheets
  - `e2e/live-fragment-submit-regressions.spec.ts` proves one leave submit creates one request and one timesheet submit creates one card
- `e2e/global-teardown.ts` now deletes dependent event/snapshot/export rows for `e2e-%` users before deleting the users themselves, so the new leave/timesheet mutations do not break teardown via foreign keys.

## Why this lane exists

The shared live-update runtime landed for roster, but the rest of the app has not been migrated to that model yet.

Confirmed remaining gaps:

- Leave creation still does not invalidate roster scopes; only approve/deny currently propagate to roster viewers. That is currently intentional pending a product decision about whether pending leave should affect roster conflict visibility.

## Concrete next actions

1. Implement `coordinator-ck3.5` by adding multi-view e2e coverage for passive viewer freshness on leave/timesheets, not just single-submit actor regressions.
2. Revisit whether leave create/delete should also invalidate roster scopes when pending leave should influence roster conflict presentation.

## Implementation notes

- Leave-driven roster invalidation is the highest-priority correctness fix because it is currently the clearest broken assumption after Auto Refresh removal.
- For timesheets, day sections are now the canonical fragment boundary. Each mounted section carries its own refetch URL, and the client adapter resyncs by refetching all currently mounted sections within the subscribed week shell.
- For leave, a coarse content fragment is acceptable first; row fragments are optional if they actually reduce churn enough to justify the complexity.
- Keep the viewer path structural: scope + fragment refs only.
- Reuse the existing client-side owner-discovery pattern in `static/app.js` rather than adding page-specific websocket bootstraps.
- HTMX forms in this repo now need both correct response shape and submit-event isolation from IHP `helpers.js`; `data-disable-javascript-submission` alone is not enough because the IHP handler will still force a second transport unless the submit event is stopped before it bubbles to `document`.

## Verification

Ran in this pass:

- `bash ./bin/in-env typecheck`
  - passed
- `bash ./bin/in-env test`
  - passed with `172 examples, 0 failures`
- `bash ./bin/in-env test --match LeaveRequestsController`
  - passed with `20 examples, 0 failures`
- `bash ./bin/in-env test --match TimesheetsController`
  - passed with `17 examples, 0 failures`
- `bash ./bin/in-env dev-start`
  - passed
- `bash ./bin/in-env dev-wait 120`
  - passed
- `bash ./bin/in-env e2e e2e/live-fragment-submit-regressions.spec.ts`
  - passed with `2 passed`
- `bash ./bin/in-env format`
  - passed
- `bash ./bin/in-env typecheck` after formatting
  - passed
- `bash ./bin/in-env dev-stop`
  - passed

Not yet run in this pass:

- Playwright coverage for passive-viewer leave/timesheet multi-view behavior
