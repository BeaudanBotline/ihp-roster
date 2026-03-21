# Helpers Runtime Decoupling Handoff

## Workstream status

- Coordinator Beads epic: `coordinator-6ye`
- Status: planning
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

## Current architectural assessment

- Short-term: keep the centralized HTMX submit isolation currently in `static/app.js`
- Long-term: remove `helpers.js` entirely once replacement work is complete
- Recommended target model:
  - HTMX for in-place partial workflows
  - native browser submits for low-frequency full-page forms unless there is a strong reason not to
  - explicit destructive-action forms instead of `.js-delete`
  - app-local date picker initialization if still desired

## Open technical decisions

These need explicit confirmation before implementation starts:

1. Keep or drop TurboLinks for ordinary page navigation?
   - Recommendation: keep only if it still pays for itself; decouple the decision from forms.
2. Are admin/profile/export/login forms acceptable as normal full-page submits?
   - Recommendation: yes, unless a specific page has a UX reason to stay partial.
3. Do we want any replacement for `.js-delete` beyond explicit forms?
   - Recommendation: no broad replacement; use real forms or a very narrow helper only where markup cost is unacceptable.
4. Keep flatpickr enhancement?
   - Recommendation: yes, if the app still prefers the enhanced picker over native browser widgets.

## Branching note

This lane currently points at the same checkout as `coordinator-ck3` only because that is where the current app state exists.

Before implementation begins, confirm whether to:

- stack directly on `weaver/roster-live-fragments`, or
- cut a fresh follow-on branch after `coordinator-ck3.5` lands

Do not assume that decision has already been made.

## Immediate next action

Start `coordinator-6ye.2` by turning the recommendations above into explicit repo policy in `AGENTS.md` / workstream docs, then implement `.js-delete` replacement first.
