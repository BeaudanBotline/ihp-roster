You are continuing the `ihp-roster` workstream `helpers-runtime-decoupling`.

Goal: retire the app's dependency on IHP `helpers.js` and converge on one coherent app-local frontend runtime.

Read first:

1. `AGENTS.md`
2. `.loom/workstreams/helpers-runtime-decoupling/context.md`
3. `.loom/workstreams/helpers-runtime-decoupling/handoff.md`
4. `Web/View/Layout.hs`
5. `static/app.js`
6. `IHP/ihp/data/static/helpers.js`

Current recommendations to implement unless code reality forces a different choice:

- use HTMX for partial/in-place workflows
- use native browser submits for low-frequency full-page workflows unless there is a clear UX reason to stay partial
- replace `.js-delete` with explicit app-owned destructive action markup, preferably real forms
- keep only the non-transport helpers that still materially help the app, most likely flatpickr/date initialization
- do not patch IHP source; make changes in app code only

Execution order:

1. claim the relevant Beads child issue under `coordinator-6ye`
2. implement the chosen slice end-to-end
3. add or update regression coverage
4. update `.loom/workstreams/helpers-runtime-decoupling/handoff.md`
5. update repo `AGENTS.md` if a stable convention changes
6. close the completed Beads child issue

Be explicit about any remaining technical decision if implementation reveals a real tradeoff the current recommendations do not settle.
