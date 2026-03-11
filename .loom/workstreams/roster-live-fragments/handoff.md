# Roster Live Fragments Handoff

## Workstream status

- Phase 1 fragment normalization is landed
- Phase 2 websocket invalidation transport is landed
- Phase 3 roster fragment refetch endpoints are landed
- Phase 4 client subscription/refetch integration is landed for roster week pages
- Phase 5 mutation coverage is partial: slot updates, row add/remove, and publish now broadcast invalidations; create/copy/import flows still rely on existing navigation/Auto Refresh behavior
- Existing repo state was checkpointed before planning in commit `2b4e99a` (`Checkpoint current repo changes`)

## Baseline verification notes

- `bash ./bin/in-env typecheck` passes after the live-fragment transport/refetch/client changes.
- `bash ./bin/in-env test --match "RosterWeeksController"` now compiles and runs the unauthenticated examples, but every DB-backed example still fails in this sandbox because the local Postgres socket at `/home/beau/documents/projects/ihp-roster/build/db/.s.PGSQL.5432` returns `Operation not permitted`.
- `bash ./bin/in-env dev-status` reports `running=false managed=false socket_ok=false pid=none db_ok=false http_ok=false db_blocked=true http_blocked=true`.
- `bash ./bin/in-env e2e e2e/roster-live-fragments.spec.ts` fails during Playwright global setup for the same socket-permission reason while seeding `e2e/fixtures/seed.sql`.
- `bash ./bin/in-env format` passes.
- `bash ./bin/in-env lint` passes after a small roster controller cleanup.

## Current architecture decision

The chosen approach is:

- immediate HTMX fragment response for the acting user
- websocket invalidation for concurrent viewers
- authorized fragment refetch for viewer updates
- Auto Refresh retained during rollout as broad fallback/correctness layer

Rejected as primary foundation:

- Auto Refresh only
- DataSync-first client rendering
- server-side components as the app-wide collaboration layer
- raw cross-user HTML broadcast as the default transport

## Current roster-specific understanding

- The acting-user gap today is in `UpdateRosterSlotAction`: impacted rows refresh, but the roster staff panel does not
- Roster rows already have stable DOM ids and OOB render helpers
- The sidebar/staff panel needs to become a first-class fragment with a stable id and render helper
- `ShowRosterWeekAction` already uses Auto Refresh, so this work must coexist safely with that behavior during rollout

## Landed in this pass

- Added a mounted websocket live-update transport in [Web/Controller/LiveUpdates.hs](/home/beau/documents/projects/ihp-roster/Web/Controller/LiveUpdates.hs) and [Web/FrontController.hs](/home/beau/documents/projects/ihp-roster/Web/FrontController.hs):
  - `/live-updates` websocket path
  - `RosterWeekScope` authorization against current venue plus live/draft visibility rules
  - subscription cleanup on close/resubscribe
- Added dedicated authorized roster fragment endpoints in [Web/Types.hs](/home/beau/documents/projects/ihp-roster/Web/Types.hs) and [Web/Controller/RosterWeeks.hs](/home/beau/documents/projects/ihp-roster/Web/Controller/RosterWeeks.hs):
  - `ShowRosterWeekContentFragmentAction`
  - `ShowRosterWeekStaffPanelFragmentAction`
  - `ShowRosterWeekRowFragmentAction`
- Added reusable roster invalidation builders in [Web/Controller/RosterWeeks.hs](/home/beau/documents/projects/ihp-roster/Web/Controller/RosterWeeks.hs):
  - `buildRosterContentFragmentRef`
  - `buildRosterStaffPanelFragmentRef`
  - `buildRosterRowFragmentRefs`
  - `broadcastRosterWeekInvalidation`
- Expanded mutation broadcasting:
  - `UpdateRosterSlotAction` now broadcasts row invalidations plus sidebar when assignment changes
  - `AddRosterRowAction` and `RemoveRosterRowAction` now broadcast coarse content + sidebar invalidations
  - `PublishRosterWeekAction` now broadcasts roster content invalidation
- Added roster shell live-subscription metadata in [Web/View/RosterWeeks/Show.hs](/home/beau/documents/projects/ihp-roster/Web/View/RosterWeeks/Show.hs).
- Added client live-fragment handling in [static/app.js](/home/beau/documents/projects/ihp-roster/static/app.js):
  - per-tab `clientId`
  - websocket subscribe/reconnect lifecycle tied to `#roster-week-shell`
  - HTMX header injection via `X-Live-Update-Client-Id`
  - targeted fragment refetch with per-target request queueing
  - blur-deferred row refetch for actively edited rows
- Added coverage in [Test/Controller/RosterWeeksSpec.hs](/home/beau/documents/projects/ihp-roster/Test/Controller/RosterWeeksSpec.hs) for:
  - unauthenticated fragment route protection
  - manager row-fragment fetch
  - hidden draft row fragments for staff
  - assignment actor response patches
- Added multi-context browser coverage in [e2e/roster-live-fragments.spec.ts](/home/beau/documents/projects/ihp-roster/e2e/roster-live-fragments.spec.ts) for same-week live updates across viewers.
- Promoted durable live-fragment conventions into [AGENTS.md](/home/beau/documents/projects/ihp-roster/AGENTS.md), [Web/Controller/AGENTS.md](/home/beau/documents/projects/ihp-roster/Web/Controller/AGENTS.md), and [Web/View/AGENTS.md](/home/beau/documents/projects/ihp-roster/Web/View/AGENTS.md).

## Recommended implementation starting point

The next pass should be a verification and rollout-hardening pass in a healthy local environment, then decide whether any remaining mutation types need targeted invalidations before narrowing Auto Refresh.

## Candidate abstraction names

- Work branch: `weaver/roster-live-fragments`
- Scope:
  - `RosterWeekScope`
- Shared helper module:
  - `Application.Helper.LiveUpdate`
- Transport app:
  - `LiveUpdatesWSApp` or `RosterLiveWSApp`
- Response helper:
  - `respondWithRosterPatches`
- Viewer invalidation helper:
  - `broadcastRosterWeekInvalidation`

Use the names above only if they still fit the code once implementation begins.

## Known traps

- If invalidation payloads contain rendered HTML, authorization and per-viewer differences get much harder
- If the client does not track current `weekOffset` after HTMX navigation, it will stay subscribed to the wrong roster scope
- If actor and viewer updates are not deduped, the editing user may get redundant second-pass updates
- If refetch endpoints do not reuse the same render helpers as actor responses, drift will appear quickly
- If remote updates are allowed to overwrite focused inputs immediately, collaborative editing will feel broken

## Next actions

1. Restore a working local DB/server path outside this sandbox:
   - get `/home/beau/documents/projects/ihp-roster/build/db/.s.PGSQL.5432` reachable
   - get `bash ./bin/in-env dev-status` to report `db_ok=true` and `http_ok=true`
2. Re-run verification in that healthy environment:
   - `bash ./bin/in-env test --match "RosterWeeksController"`
   - `bash ./bin/in-env e2e e2e/roster-assignment-sidebar.spec.ts`
   - `bash ./bin/in-env e2e e2e/roster-live-fragments.spec.ts`
3. If the new multi-viewer flow is clean, extend invalidation coverage to any remaining roster-affecting workflows still relying only on Auto Refresh:
   - copy/import/create week flows
   - staff-edit workflows launched from roster when they change visible sidebar content
4. After live coverage is proven complete, review whether roster can narrow Auto Refresh or should keep it as the broad fallback.
