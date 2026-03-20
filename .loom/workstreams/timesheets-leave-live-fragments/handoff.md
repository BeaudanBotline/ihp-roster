# Timesheets And Leave Live Fragments Handoff

## Workstream status

- Coordinator Beads epic: `coordinator-ck3`
- Status: planned and ready for implementation
- Starting branch context: local checkout on `weaver/roster-live-fragments`

## Why this lane exists

The shared live-update runtime landed for roster, but the rest of the app has not been migrated to that model yet.

Confirmed gaps:

- `Application/Helper/Controller.hs` still uses `triggerRosterConflictRecomputeForLeave` to bump `roster_weeks.updatedAt` for leave-driven roster conflict changes. That helper explicitly says it exists so roster pages auto-refresh, which is now stale.
- `Web/Controller/LeaveRequests.hs` has HTMX support only for creating a leave request dialog. Approve, deny, and delete still redirect and do not broadcast live invalidations.
- `Web/Controller/Timesheets.hs` has HTMX actor patches for some create/update flows, but no cross-viewer live invalidation path and no fragment endpoints/scope metadata for concurrent viewers.
- `Application/Helper/LiveUpdate.hs` currently defines only `RosterWeekScope` and roster fragment keys.

## Concrete next actions

1. Implement `coordinator-ck3.1` by extending the shared live-update scope/fragment model for leave and timesheet use.
2. Implement `coordinator-ck3.2` by replacing the leave `updatedAt` touch path with explicit roster invalidations for affected week scopes.
3. Implement `coordinator-ck3.3` by wiring live fragments into the leave page itself.
4. Implement `coordinator-ck3.4` by wiring live fragments into the timesheet week page.
5. Finish with `coordinator-ck3.5` by adding controller/e2e coverage and recording verification.

## Implementation notes

- Leave-driven roster invalidation is the highest-priority correctness fix because it is currently the clearest broken assumption after Auto Refresh removal.
- For timesheets, the existing day-section partitioning is probably the right first fragment boundary.
- For leave, a coarse content fragment is acceptable first; row fragments are optional if they actually reduce churn enough to justify the complexity.
- Keep the viewer path structural: scope + fragment refs only.
- Reuse the existing client-side owner-discovery pattern in `static/app.js` rather than adding page-specific websocket bootstraps.

## Verification target

Minimum expected verification once implementation is complete:

- `bash ./bin/in-env typecheck`
- `bash ./bin/in-env test`
- targeted Playwright coverage for new leave/timesheet live-update specs

Record exact commands and pass/fail outcomes here after implementation.
