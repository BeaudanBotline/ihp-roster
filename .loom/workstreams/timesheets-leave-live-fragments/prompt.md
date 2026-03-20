# Agent Execution Prompt

You are implementing the tracked `timesheets-leave-live-fragments` workstream for this repository.

## Assigned objective

Extend the existing roster live-fragment architecture so it also covers:

- leave-driven roster conflict freshness
- leave request page concurrency
- timesheet week page concurrency

Use the already-landed shared live-update transport and client model as the foundation.

This workstream is part of:

- roadmap: `IMPLEMENTATION_PLAN.md`
- pipelines: `plans/20-roster-and-conflicts.md` and `plans/30-timesheets-and-leave.md`
- focus area: reuse the roster live-fragment pattern for leave and timesheets without reintroducing Auto Refresh

## Required read order

1. `AGENTS.md`
2. `.loom/workstreams/timesheets-leave-live-fragments/context.md`
3. `.loom/workstreams/timesheets-leave-live-fragments/handoff.md`
4. `IMPLEMENTATION_PLAN.md`
5. `plans/20-roster-and-conflicts.md`
6. `plans/30-timesheets-and-leave.md`
7. `specs/04-roster-and-conflict-rules.md`
8. `specs/05-timesheets-and-leave.md`
9. `specs/08-ihp-implementation-spec.md`
10. `specs/09-testing-and-acceptance.md`
11. Relevant subdirectory `AGENTS.md` files before editing files there

## Required process

1. Start from the current local `weaver/roster-live-fragments` branch state.
2. Implement the work in the phase order defined in `context.md`.
3. Fix the leave-to-roster freshness bug before broadening to full leave/timesheet page coverage.
4. Keep actor responses HTMX-driven and viewer updates websocket-invalidated plus fragment-refetched.
5. Add tests for every new fragment route and live-update behavior you touch.
6. Run the required verification commands from repo guidance.
7. Update `.loom/workstreams/timesheets-leave-live-fragments/handoff.md` with concrete outcomes and remaining risks.
8. Promote any durable repo-wide live-update conventions back into repo `AGENTS.md` files if the implementation proves them out.
9. Commit coherent milestones and push the branch when the assigned slice is complete.

## Constraints

- Do not reintroduce `initAutoRefresh`, `autoRefresh`, or `ihp-auto-refresh.js`.
- Do not replace the existing HSX + HTMX architecture with SPA/DataSync rendering.
- Do not broadcast rendered HTML cross-user by default.
- Keep venue and role authorization explicit on subscriptions and fragment GET actions.
- Do not drift into admin/config realtime work in this lane.

## Output expectation

- Shared live-update runtime extended cleanly for leave and timesheet scopes
- Leave approval/denial updates that refresh passive roster viewers correctly
- Leave request page live fragments
- Timesheet week live fragments
- Controller and Playwright coverage for the new multi-view behavior
- Updated handoff with exact verification results
