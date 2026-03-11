# Roster Live Fragments Handoff

## Workstream status

- Phase 1 fragment normalization is landed
- Phase 2 websocket invalidation transport is landed
- Phase 3 roster fragment refetch endpoints are landed
- Phase 4 client subscription/refetch integration is landed for roster week pages
- Phase 5 mutation coverage is partial: slot updates, row add/remove, and publish now broadcast invalidations; create/copy/import flows still rely on existing navigation/Auto Refresh behavior
- Existing repo state was checkpointed before planning in commit `2b4e99a` (`Checkpoint current repo changes`)

## Baseline verification notes

- `bash ./bin/in-env dev-start` / `bash ./bin/in-env dev-wait 120` succeeds in this environment and reports `running=true managed=true db_ok=true http_ok=true`.
- `bash ./bin/in-env typecheck` passes after the actor/viewer roster update fixes.
- `bash ./bin/in-env test --match "RosterWeeksController"` passes with DB-backed controller coverage.
- `bash ./bin/in-env lint` passes after the roster/view/live-update changes.
- `bash ./bin/in-env node ./node_modules/.bin/playwright test e2e/roster-assignment-sidebar.spec.ts e2e/roster-live-fragments.spec.ts e2e/roster-duplicate-conflicts.spec.ts` passes.

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

- `UpdateRosterSlotAction` now uses a full `#roster-content` OOB refresh for the acting browser so multi-row conflict changes stay correct.
- Viewer updates still stay fragment-scoped: websocket invalidation plus authorized refetch of plain row/sidebar/content fragments.
- Roster inputs now sync against `#roster-week-shell`, not `#roster-content`, because actor-side content refreshes replace the inner content node.
- Row-fragment refetches return plain `<tr>` markup and the client replaces those DOM nodes directly rather than routing them through generic `htmx.swap`.
- `ShowRosterWeekAction` still uses Auto Refresh as the broad fallback during rollout.

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
- Fixed the actor-path conflict/sidebar regressions in [Web/Controller/RosterWeeks.hs](/home/beau/documents/projects/ihp-roster/Web/Controller/RosterWeeks.hs) and [Web/View/RosterWeeks/Show.hs](/home/beau/documents/projects/ihp-roster/Web/View/RosterWeeks/Show.hs):
  - `UpdateRosterSlotAction` now returns `renderRosterContentFragmentOob` for the acting browser
  - roster slot inputs now use `hx-sync="#roster-week-shell:queue last"`
- Fixed the viewer-path row corruption in [Web/Controller/RosterWeeks.hs](/home/beau/documents/projects/ihp-roster/Web/Controller/RosterWeeks.hs) and [static/app.js](/home/beau/documents/projects/ihp-roster/static/app.js):
  - `ShowRosterWeekRowFragmentAction` now returns plain row fragments instead of OOB row wrappers
  - client refetch replacement now parses and replaces fragment roots directly instead of using generic `htmx.swap` for table rows
- Hardened e2e determinism in [e2e/fixtures/seed.sql](/home/beau/documents/projects/ihp-roster/e2e/fixtures/seed.sql) by deleting mutable venue-scoped roster/leave/timesheet rows before reseeding fixed fixtures.
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
  - assignment actor response patch shape
  - duplicate-conflict row fragment rendering after mutation
- Added multi-context browser coverage in:
  - [e2e/roster-live-fragments.spec.ts](/home/beau/documents/projects/ihp-roster/e2e/roster-live-fragments.spec.ts) for same-week live updates across viewers
  - [e2e/roster-duplicate-conflicts.spec.ts](/home/beau/documents/projects/ihp-roster/e2e/roster-duplicate-conflicts.spec.ts) for actor/viewer duplicate-conflict highlighting plus viewer grid integrity
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

1. Extend invalidation coverage to any remaining roster-affecting workflows still relying only on Auto Refresh:
   - copy/import/create week flows
   - staff-edit workflows launched from roster when they change visible sidebar content
2. After live coverage is proven complete, review whether roster can narrow Auto Refresh or should keep it as the broad fallback.
