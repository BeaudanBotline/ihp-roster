# Roster Live Fragments Handoff

## Workstream status

- Workstream created from architecture planning only
- No implementation has landed for the live-fragment transport yet
- Existing repo state was checkpointed before planning in commit `2b4e99a` (`Checkpoint current repo changes`)

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

## Recommended implementation starting point

Start with Phase 1 from `context.md`:

1. make the staff panel fragment explicit
2. unify actor-facing roster patch assembly
3. fix immediate local sidebar refresh for slot assignment changes

Only after that should transport and subscription code be added.

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

1. create `weaver/roster-live-fragments` from `roster`
2. run baseline verification on that branch
3. implement Phase 1 fragment normalization and local sidebar refresh
4. add a single-user test proving immediate sidebar refresh
5. then proceed to websocket invalidation and fragment refetch
