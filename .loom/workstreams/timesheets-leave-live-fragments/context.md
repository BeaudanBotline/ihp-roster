# Timesheets And Leave Live Fragments Context

## Objective

Extend the shared live-fragment collaboration pattern beyond roster so that:

- leave approval and denial push roster conflict changes to already-open roster viewers
- leave request pages stay fresh across concurrent viewers
- timesheet week pages stay fresh across concurrent viewers
- HTMX remains the actor path and websocket invalidation plus authorized fragment refetch remains the viewer path

This workstream follows the completed `roster-live-fragments` lane and reuses its transport/client architecture rather than inventing a second realtime model.

## Required read order

1. `AGENTS.md`
2. `IMPLEMENTATION_PLAN.md`
3. `plans/20-roster-and-conflicts.md`
4. `plans/30-timesheets-and-leave.md`
5. `specs/04-roster-and-conflict-rules.md`
6. `specs/05-timesheets-and-leave.md`
7. `specs/08-ihp-implementation-spec.md`
8. `specs/09-testing-and-acceptance.md`
9. `Web/Controller/AGENTS.md`
10. `Web/View/AGENTS.md`
11. `e2e/AGENTS.md`
12. `.loom/workstreams/timesheets-leave-live-fragments/handoff.md`

## Branch expectations

- Base branch: `roster`
- Current implementation branch: `weaver/roster-live-fragments`

Use the existing local live-fragment branch state as the implementation starting point. Do not restart from the pre-live-fragment `roster` branch unless explicitly instructed.

## Scope constraints

- Reuse the shared live-update runtime in `Application/Helper/LiveUpdate.hs` and `static/app.js`.
- Keep server-rendered HSX fragments canonical.
- Keep authorization on both subscriptions and fragment GET endpoints.
- Do not reintroduce IHP Auto Refresh assumptions.
- Do not replace HTMX actor responses with client-side rendering.
- Do not broaden this lane into admin/config or export collaboration work.

## Concrete implementation phases

### Phase 1. Generalize the shared runtime

- Extend `LiveUpdateScope` and `LiveFragmentKey` beyond roster-only cases.
- Add only the scopes and fragment kinds actually needed for leave and timesheets.
- Preserve roster behavior and reconnect/version semantics while generalizing.

### Phase 2. Fix leave-driven roster freshness

- Replace the stale `triggerRosterConflictRecomputeForLeave` `updatedAt` touch pattern.
- On leave approval or denial, compute affected week offsets and broadcast explicit roster invalidations for the affected venue/week scopes.
- Keep roster conflict recomputation and invalidation in a safe post-transaction shape.

### Phase 3. Add leave-page live fragments

- Give the leave page a stable subscription owner and scope metadata.
- Add authorized leave fragment endpoints.
- Make create/approve/deny/delete return immediate actor patches and broadcast viewer invalidations.
- Keep manager/staff visibility rules consistent under fragment refetch.

### Phase 4. Add timesheet-page live fragments

- Give the timesheet week shell a scope and stable fragment boundaries.
- Prefer day-section or entry-card fragments instead of whole-page redraws.
- Make create/update/delete/approve/unapprove send explicit invalidations after commit.
- Preserve existing edit-window and role rules under fragment refetch.

### Phase 5. Verification

- Add controller coverage for new fragment routes and mutation behavior.
- Add Playwright coverage for:
  - manager/staff leave page concurrency
  - leave-driven roster conflict freshness
  - manager/staff timesheet week concurrency
- Record the exact verification commands and outcomes in `handoff.md`.

## Beads mapping

- Epic: `coordinator-ck3`
- Shared runtime task: `coordinator-ck3.1`
- Leave-to-roster invalidation bug: `coordinator-ck3.2`
- Leave page live fragments: `coordinator-ck3.3`
- Timesheet page live fragments: `coordinator-ck3.4`
- Verification: `coordinator-ck3.5`
