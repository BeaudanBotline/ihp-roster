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

## Why this lane exists

The shared live-update runtime landed for roster, but the rest of the app has not been migrated to that model yet.

Confirmed remaining gaps:

- `Web/Controller/LeaveRequests.hs` still has HTMX support only for creating a leave request dialog. Approve, deny, and delete still redirect and do not yet broadcast leave-page invalidations.
- `Web/Controller/Timesheets.hs` has HTMX actor patches for some create/update flows, but no cross-viewer live invalidation path and no fragment endpoints/scope metadata for concurrent viewers.
- `Application/Helper/LiveUpdate.hs` currently defines only `RosterWeekScope` and roster fragment keys.

## Concrete next actions

1. Implement `coordinator-ck3.1` by extending the shared live-update scope/fragment model for leave and timesheet use.
2. Implement `coordinator-ck3.3` by wiring live fragments into the leave page itself.
3. Implement `coordinator-ck3.4` by wiring live fragments into the timesheet week page.
4. Finish with `coordinator-ck3.5` by adding controller/e2e coverage and recording verification.

## Implementation notes

- Leave-driven roster invalidation is the highest-priority correctness fix because it is currently the clearest broken assumption after Auto Refresh removal.
- For timesheets, the existing day-section partitioning is probably the right first fragment boundary.
- For leave, a coarse content fragment is acceptable first; row fragments are optional if they actually reduce churn enough to justify the complexity.
- Keep the viewer path structural: scope + fragment refs only.
- Reuse the existing client-side owner-discovery pattern in `static/app.js` rather than adding page-specific websocket bootstraps.

## Verification

Ran in this pass:

- `bash ./bin/in-env typecheck`
  - passed
- `bash ./bin/in-env test`
  - passed with `159 examples, 0 failures`
- `bash ./bin/in-env test --match LeaveRequestsController`
  - first run failed because the local test DB socket was not up yet (`build/db/.s.PGSQL.5432` missing)
  - after `bash ./bin/in-env dev-start` and `bash ./bin/in-env dev-wait 120`, rerun passed with `13 examples, 0 failures`

Not yet run in this pass:

- Playwright coverage for leave/timesheet multi-view behavior
