# Roster Live Fragments Handoff

## Workstream status

- Workstream created from architecture planning only
- Phase 1 fragment normalization has started on `weaver/roster-live-fragments`
- No implementation has landed for the live-fragment transport yet
- Existing repo state was checkpointed before planning in commit `2b4e99a` (`Checkpoint current repo changes`)

## Baseline verification notes

- Initial `bash ./bin/in-env typecheck` and `bash ./bin/in-env test` failed because `build/Generated/Types.hs` was missing from the worktree state.
- Running `bash ./bin/in-env regen-types` restored the generated modules and unblocked compilation.
- After regenerating types, `bash ./bin/in-env typecheck` passes.
- `bash ./bin/in-env test` still cannot complete in this environment because the expected Postgres socket at `/workspace/build/db/.s.PGSQL.5432` is absent.
- `bash ./bin/in-env dev-start` is currently unusable here because its wrapper calls `setsid`, which is not installed in the container.
- A direct background `start` launch also failed to produce a reachable DB or HTTP server, and the Nix-store `devenv` binary reports `cannot execute: required file not found`.

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

- Added stable roster fragment ids in [Web/View/RosterWeeks/Show.hs](/workspace/Web/View/RosterWeeks/Show.hs):
  - `rosterContentFragmentId`
  - `rosterStaffPanelFragmentId`
- Promoted the manager sidebar to a reusable fragment helper with an OOB variant:
  - `renderRosterStaffPanelFragment`
  - `renderRosterStaffPanelFragmentOob`
- Added `respondWithRosterPatches` in [Web/Controller/RosterWeeks.hs](/workspace/Web/Controller/RosterWeeks.hs) so actor responses can reuse one render-data fetch for rows plus sidebar fragments.
- Updated `UpdateRosterSlotAction` to refresh the staff panel only when the assigned staff changes (`previousStaffId /= updatedSlot.staffId`).
- Added DB-backed controller coverage in [Test/Controller/RosterWeeksSpec.hs](/workspace/Test/Controller/RosterWeeksSpec.hs) for the assignment actor response shape.
- Added browser coverage in [e2e/roster-assignment-sidebar.spec.ts](/workspace/e2e/roster-assignment-sidebar.spec.ts) for immediate sidebar refresh after assigning a linked staff member.

## Recommended implementation starting point

Phase 1 core pieces above are now in place. The next pass should verify them in a healthy DB/server environment, then proceed to Phase 2 websocket invalidation + Phase 3 fragment refetch endpoints.

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

1. Restore a working local DB/server path for verification:
   - either fix `dev-start`/`devenv` in the environment
   - or start the IHP stack manually so `/workspace/build/db/.s.PGSQL.5432` and `http://localhost:8000` are live
2. Run targeted verification for the landed Phase 1 slice:
   - `bash ./bin/in-env test --match "returns row and staff panel patches when a slot assignment changes"`
   - `bash ./bin/in-env e2e e2e/roster-assignment-sidebar.spec.ts`
3. If Phase 1 verifies cleanly, begin Phase 2 transport work:
   - add reusable live update types/helper module
   - add websocket subscription/auth path
4. Then add Phase 3 fragment refetch endpoints that reuse the new fragment helpers.
