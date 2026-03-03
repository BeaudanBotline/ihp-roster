# Pipeline 60 — Template Extraction

Read after `IMPLEMENTATION_PLAN.md`.

## Goal

Extract reusable, project-agnostic infrastructure from the `roster` branch back into `master` so that `master` serves as a powerful general-purpose IHP template for new projects forked by agents or developers.

## Context

The `roster` branch has 59 commits over `master` containing ~7,200 lines of additions. Most are project-specific (roster, timesheets, leave, staff, venue domain code), but a significant amount is generic infrastructure that any IHP project would benefit from: dev automation, overlay system, dark-theme tokens, AGENTS.md documentation, e2e helpers, and reusable UI components.

This plan covers only the extraction of project-agnostic elements. Project-specific domain code stays exclusively on the `roster` branch.

## Branch Strategy

All work targets `master`. Each phase produces one or more commits on `master`. After all phases land, `roster` should rebase or merge from `master` to pick up any reformatting or structural alignment, but no `roster`-specific code should appear on `master`.

Work within a phase is sequential (each slice depends on the prior). Phases themselves are sequential — later phases may reference files created or modified by earlier phases.

## Non-Goals

- Migrating any domain schema (roster_weeks, staff, timesheets, leave_requests, venues, venue_memberships, venue_config)
- Migrating domain controllers, views, helpers, or tests
- Migrating specs/ or project-specific plans/
- Changing any behavior on the `roster` branch

## Dependencies

- Must be done on a clean `master` checkout
- No dependency on running `devenv up` — these are file-only changes verified by `typecheck`
- Phase 3 (overlay system) depends on Phase 2 (Bootstrap upgrade + layout)
- Phase 4 (AGENTS.md) can proceed independently after Phase 1

---

## Phase 1 — Dev Automation and Build Fixes

### Slice 1.1: Nix string escaping fix
- **Status:** [ ]
- **Source commit:** `b30edf4`
- **Strategy:** Cherry-pick directly onto `master`.
- **Files:**
  - `flake.nix`
- **Verification:** `direnv exec . typecheck`

### Slice 1.2: Dev-server lifecycle scripts
- **Status:** [ ]
- **Source commits:** `ca2f48f`, `6ff3e85`
- **Strategy:** Cherry-pick or extract from these commits. The scripts to add to `flake.nix` are:
  - `dev-start` — start IHP `start` in background, write pid/log to `.devenv/agent/`, fail fast on startup crash
  - `dev-stop` — stop background server by pid, handle stale pid files, report unmanaged healthy servers
  - `dev-status` — health check (process + socket + DB + HTTP), handle restricted sandbox environments where network checks are blocked
  - `dev-wait` — poll `dev-status` until healthy, configurable timeout, print diagnostics on failure
- **Files:**
  - `flake.nix` — add the four script blocks after the existing `e2e-report` script
- **Verification:** Run `direnv exec . dev-start && direnv exec . dev-wait && direnv exec . dev-status && direnv exec . dev-stop` with `devenv up` active.

### Slice 1.3: hlint QuasiQuotes fix
- **Status:** [ ]
- **Source commit:** `f330df7` (partial — only the hlint change)
- **Strategy:** In `flake.nix`, change the two `hlint` invocations to include `-XQuasiQuotes`:
  ```
  # lint script exec line:
  exec hlint -XQuasiQuotes "$@"
  # lint default target line:
  hlint -XQuasiQuotes Main.hs Web/ Application/Helper/ Config/
  ```
- **Files:**
  - `flake.nix` (2 lines)
- **Verification:** `direnv exec . lint`

### Slice 1.4: Makefile IHP_LIB fallback
- **Status:** [ ]
- **Source:** Makefile diff from roster branch
- **Strategy:** Add the `IHP_LIB_FALLBACK` resolution block before `include ${IHP}/Makefile.dist`:
  ```makefile
  # Resolve IHPSchema.sql across IHP env layouts.
  IHP_LIB_FALLBACK := $(firstword \
          $(wildcard ${IHP}/lib/IHP) \
          $(wildcard ${PWD}/IHP/ihp-ide/data))

  ifeq ($(wildcard ${IHP_LIB}/IHPSchema.sql),)
  ifneq (${IHP_LIB_FALLBACK},)
  IHP_LIB := ${IHP_LIB_FALLBACK}
  endif
  endif
  ```
- **Files:**
  - `Makefile`
- **Verification:** `make db` with `devenv up` active (should not error on missing IHPSchema.sql).

### Slice 1.5: Config.hs trailing newline fix
- **Status:** [ ]
- **Strategy:** Ensure `Config/Config.hs` ends with a newline after `pure ()`.
- **Files:**
  - `Config/Config.hs`
- **Verification:** `direnv exec . typecheck`

### Slice 1.6: Authenticated screenshot script
- **Status:** [ ]
- **Source commit:** `fad4ea5` (partial)
- **Strategy:** Copy `e2e/screenshot-page.mjs` from the roster branch as-is. Add the `screenshot-page` script entry to `flake.nix`:
  ```nix
  screenshot-page.exec = ''
      exec node ./e2e/screenshot-page.mjs "$@"
  '';
  ```
- **Files:**
  - `e2e/screenshot-page.mjs` (new — copy verbatim from roster branch)
  - `flake.nix` (add script entry)
- **Verification:** `direnv exec . screenshot-page --help` should print usage.

---

## Phase 2 — Dark Theme and Layout Foundation

### Slice 2.1: Vendor Bootstrap 5.3.8
- **Status:** [ ]
- **Source commit:** `abc4f7d` (partial)
- **Strategy:** Copy the vendored Bootstrap 5.3.8 files from roster. Update `Web/View/Layout.hs` to reference the new paths. Remove the old `bootstrap-5.2.1` references from layout (but do not delete the old vendor files from `IHP/` — they ship with IHP itself).
- **Files:**
  - `static/vendor/bootstrap-5.3.8/bootstrap.min.css` (new — copy from roster)
  - `static/vendor/bootstrap-5.3.8/bootstrap.bundle.min.js` (new — copy from roster)
  - `Web/View/Layout.hs` — update stylesheet and script references:
    - `/vendor/bootstrap-5.2.1/bootstrap.min.css` → `/vendor/bootstrap-5.3.8/bootstrap.min.css`
    - Remove popper.min.js (bundled in bootstrap.bundle.min.js)
    - `/vendor/bootstrap-5.2.1/bootstrap.min.js` → `/vendor/bootstrap-5.3.8/bootstrap.bundle.min.js`
    - Add HTMX CDN script: `<script src="https://unpkg.com/htmx.org@1.9.12"></script>`
    - Add Bootstrap Icons CDN: `<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css"/>`
- **Verification:** `direnv exec . typecheck`

### Slice 2.2: Dark-mode CSS token system
- **Status:** [ ]
- **Source:** `static/app.css` from roster branch (generic tokens only)
- **Strategy:** Replace the empty `static/app.css` with the generic dark-mode token system. Include **only** these sections from the roster branch's `app.css`:
  - `:root` variables (lines 1-24, but **remove** `--roster-*` variables)
  - `html { scrollbar-gutter: stable; }` (line 26-28)
  - `body.theme-dark` gradient background (lines 30-33)
  - Link color overrides (lines 35-41)
  - `.app-shell`, `.app-content`, `.app-header` (lines 43-55)
  - `.navbar-brand` colors (lines 57-63)
  - `.app-page-auth`, `.app-auth-card`, `.app-panel`, `.app-auth-body`, `.app-panel-body` (lines 65-97)
  - `.app-form-width`, `.app-muted` (lines 99-101)
  - `.card`, `.card-header` overrides (lines 103-111)
  - `.breadcrumb` overrides (lines 113-116)
  - `.nav-tabs` overrides (lines 118-131)
  - `.table` overrides (lines 133-141)
  - `.form-control`, `.form-select` overrides (lines 143-158)
  - `.btn-outline-*` overrides (lines 160-179)
  - Toast classes: `.app-toast-host*`, `.app-toast`, `.app-toast-body`, `.app-toast-title`, `.app-toast-close`, `.app-toast-leaving` (lines ~275-368)
  - `@media print` rule for `.btn`, `.breadcrumb` (simplified — remove roster-specific selectors)

  **Exclude** all `.roster-*`, `.conflict-*`, `.time-picker-*`, `.slot-*`, `.day-*` classes — those are project-specific.
- **Files:**
  - `static/app.css`
- **Verification:** Visual check with `devenv up` running.

### Slice 2.3: Layout dark-mode shell and generic authenticated header
- **Status:** [ ]
- **Strategy:** Update `Web/View/Layout.hs` to use the dark-mode shell structure. The template header should be minimal — just a brand link and logout button. Projects will customize nav links.
- **Changes to `defaultLayout`:**
  - Add `data-bs-theme="dark"` to `<html>` tag
  - Add `class="theme-dark"` to `<body>`
  - Replace the inner `<div class="container mt-4">` with the app-shell pattern:
    ```hsx
    <div class="app-shell">
        {renderAppHeader}
        <main class="app-content container py-4">
            {renderFlashMessages}
            {inner}
        </main>
    </div>
    ```
  - Add an empty `<div id="dialog-overlay-mount"></div>` after app-shell (placeholder for Phase 3)
  - Add `{modal}` after the overlay mount
- **Add `renderAppHeader`** function:
  ```haskell
  renderAppHeader :: (?context :: ControllerContext) => Html
  renderAppHeader =
      case currentUserOrNothing of
          Just _ -> [hsx|
              <header class="app-header border-bottom">
                  <nav class="navbar navbar-expand-md container py-2">
                      <a class="navbar-brand fw-semibold" href={WelcomeAction}>App</a>
                      <div class="navbar-nav ms-auto">
                          <a class="btn btn-outline-danger btn-sm js-delete js-delete-no-confirm" href={DeleteSessionAction}>logout</a>
                      </div>
                  </nav>
              </header>
          |]
          Nothing -> mempty
  ```
- **Files:**
  - `Web/View/Layout.hs`
- **Verification:** `direnv exec . typecheck`

---

## Phase 3 — Overlay System

Depends on Phase 2 (Layout must have the dark-mode shell and mount points).

### Slice 3.1: Overlay config types and renderers in Helper/View.hs
- **Status:** [ ]
- **Strategy:** Add the generic overlay infrastructure to `Application/Helper/View.hs`. Copy from the roster branch but **exclude** all project-specific helpers (anything referencing `Staff`, `TimesheetEntry`, `RosterWeek`, `LeaveRequest`, `Venue`).
- **Add these types and functions:**
  - `dialogOverlayMountId`, `htmxModalMountId`, `toastOverlayMountId` — mount ID constants
  - `OverlayFormMode` (`HtmxOverlayForm | PageOverlayForm`)
  - `OverlayButtonAction` (`OverlayCloseAction | OverlaySubmitFormAction Text | OverlayNavigateAction Text`)
  - `OverlayButton` record
  - `DialogOverlayConfig` record
  - `ToastOverlayConfig` record
  - `ToastOverlayPosition` enum
  - `PartialNavigationLink` record
  - `defaultOverlayButtons` — standard Cancel/Save pair
  - `renderDialogOverlay` — full dialog overlay renderer
  - `renderDialogOverlayFooter`, `renderDialogOverlayButton` — footer helpers
  - `renderPageDialogModal` — `setModal`-based fallback renderer
  - `renderPageDialogFooter`, `renderPageDialogButton` — page-modal footer helpers
  - `renderPartialNavigationLink` — HTMX partial-navigation anchor
  - `renderToastOverlayHost`, `renderToastOverlayHostOob` — toast container renderers
  - `toastOverlayHostClass` — position-based class helper
  - `renderToastOverlay`, `renderToastCopy` — individual toast renderer
- **Required imports to add:**
  ```haskell
  import qualified Data.Text as Text
  import IHP.ViewPrelude
  import Generated.Types
  import Web.Types
  import Web.Routes ()
  ```
- **Do NOT include:** `renderTimesheetForm`, `renderTimesheetFormFields`, `renderStaffField`, `renderTimesheetStaffOption`, `renderTimePickerField`, `renderFieldError`, `hasErrorFor`, `renderTimesheetEntryModal`, `renderTimesheetEntryDialog`, `renderStaffEditPageModal`, `renderStaffEditDialog`, `linkedActiveStaffForRosterPanel`, `isTrialStaff`, `currentUserIsManager`, `currentUserIsAdmin`, `formatDateDisplay`, time-picker helpers, or any function referencing domain types.
- **Files:**
  - `Application/Helper/View.hs`
- **Verification:** `direnv exec . typecheck`

### Slice 3.2: Dialog overlay and toast JavaScript
- **Status:** [ ]
- **Strategy:** Replace the stub `static/app.js` with the generic overlay JS from the roster branch. Include:
  - Turbolinks + HTMX re-process hook (line 1-6 of roster app.js)
  - `enableDialogOverlayMount` IIFE — full dialog open/close/escape/focus/backdrop/body-lock behavior
  - `enableToastOverlayHost` IIFE — toast init/dismiss/auto-hide behavior

  **Exclude:** `enableRosterGridAutoRefreshDeferral`, `enableQuarterHourTimePicker`, `enableBreakTimeToggle` — all project-specific.
- **Files:**
  - `static/app.js`
- **Verification:** Visual check — dialog mount should exist in DOM, no JS console errors.

### Slice 3.3: Wire overlay mounts into Layout.hs
- **Status:** [ ]
- **Strategy:** Update `Web/View/Layout.hs` `defaultLayout` to include:
  - `<div id={dialogOverlayMountId}></div>` (already added as placeholder in 2.3 — update to use the imported constant)
  - `{renderFlashOverlayToasts}` — a function that converts IHP flash messages into toast overlays
  - Import `dialogOverlayMountId` and toast helpers from `Application.Helper.View` (already available via `Web.View.Prelude`)
- **Add `renderFlashOverlayToasts`** to `Web/View/Layout.hs`:
  ```haskell
  renderFlashOverlayToasts :: (?context :: ControllerContext) => Html
  renderFlashOverlayToasts =
      renderToastOverlayHost ToastBottomCenter (mapMaybe flashToToast (fromFrozenContext @[FlashMessage]))
      where
          flashToToast (SuccessFlashMessage msg) = Just ToastOverlayConfig
              { toastOverlayTitle = Nothing
              , toastOverlayMessage = msg
              , toastOverlayClass = "border-success"
              , toastOverlayAutoHideMs = 4000
              }
          flashToToast (ErrorFlashMessage msg) = Just ToastOverlayConfig
              { toastOverlayTitle = Just "Error"
              , toastOverlayMessage = msg
              , toastOverlayClass = "border-danger"
              , toastOverlayAutoHideMs = 0
              }
  ```
  This replaces `{renderFlashMessages}` in the layout — flash messages now appear as overlay toasts instead of inline alerts.
- **Required import in Layout.hs:**
  ```haskell
  import IHP.FlashMessages.Types (FlashMessage (..))
  ```
- **Files:**
  - `Web/View/Layout.hs`
- **Verification:** `direnv exec . typecheck`. Visual: trigger a flash message and confirm it renders as a bottom-center toast.

---

## Phase 4 — AGENTS.md Documentation

No code dependencies — can proceed after Phase 1 or in parallel with Phases 2-3.

### Slice 4.1: Root AGENTS.md updates
- **Status:** [ ]
- **Strategy:** Merge the generic additions from the roster branch `AGENTS.md` diff into master's `AGENTS.md`. Include:
  - **Dev automation section:** `dev-start`, `dev-stop`, `dev-status`, `dev-wait` documentation and the recommended automation snippet
  - **`XDG_CACHE_HOME` note** for nix fetcher cache
  - **Overlay architecture section** — the three-lane overlay model (dialog / picker / toast), declarative config preference, HTMX fragment guidance
  - **Overlay implementation plan section** — mount locations, toast placement, controller HTMX-first guidance
  - **Verification workflow additions** — e2e test runner docs

  **Exclude or generalize:**
  - Remove roster/timesheet/leave-specific nav link references
  - Remove "Roster Week Navigation Conventions" section (project-specific)
  - Remove "Current UI Patterns" section (project-specific)
  - Remove "Planning Files" section unless `plans/` structure is kept on master
- **Files:**
  - `AGENTS.md`
- **Verification:** Read the file; ensure no domain-specific references remain.

### Slice 4.2: Application/AGENTS.md
- **Status:** [ ]
- **Strategy:** Create `Application/AGENTS.md` using the roster branch version but generalized:
  - Keep: Schema conventions, helper file descriptions, QueryBuilder cheat sheet, overlay helper guidance
  - Remove: References to venue/roster/staff/leave-specific context helpers
  - Generalize: "request-scoped business context" example — keep the pattern, remove `currentVenue` / `currentVenueMembership` specifics
- **Files:**
  - `Application/AGENTS.md` (new)
- **Verification:** Read the file.

### Slice 4.3: Web/Controller/AGENTS.md
- **Status:** [ ]
- **Strategy:** Create `Web/Controller/AGENTS.md` using the roster branch version but generalized:
  - Keep: 4-file controller creation checklist, common patterns, overlay controller pattern, state transition pattern
  - Remove: "Navigation Controller Pattern" section (roster-specific `weekOffset` pattern)
  - Generalize: overlay examples — remove `RosterWeeksAction` / `ShowRosterWeekAction` references, use generic action names
- **Files:**
  - `Web/Controller/AGENTS.md` (new)
- **Verification:** Read the file.

### Slice 4.4: Web/View/AGENTS.md
- **Status:** [ ]
- **Strategy:** Create `Web/View/AGENTS.md` using the roster branch version but generalized:
  - Keep: View creation pattern, HSX rules, form pattern, key imports, theming pattern (dark mode), overlay pattern, global header pattern
  - Remove: "Roster HTMX Pattern", "Roster Week Controls", "Reusable Time Picker Pattern" sections
  - Generalize: header pattern — use generic nav link placeholders, not roster/timesheet/leave/admin
- **Files:**
  - `Web/View/AGENTS.md` (new)
- **Verification:** Read the file.

### Slice 4.5: e2e/AGENTS.md
- **Status:** [ ]
- **Strategy:** Create `e2e/AGENTS.md` using the roster branch version but generalized:
  - Keep: Running tests, prerequisites, writing new tests (template, login pattern), test data convention, assertion style, operational notes, authenticated screenshot helper, common selectors, debugging
  - Remove: Roster/timesheet-specific assertion advice, venue-specific seed data notes
  - Generalize: post-login URL expectations — use generic route patterns, not `RosterWeeks`
- **Files:**
  - `e2e/AGENTS.md` (new)
- **Verification:** Read the file.

---

## Phase 5 — Generic Controller and View Utilities

### Slice 5.1: HTMX controller helpers
- **Status:** [ ]
- **Strategy:** Add generic HTMX helpers to `Application/Helper/Controller.hs`:
  ```haskell
  -- | True when the current request came from htmx.
  isHtmxRequest :: (?context :: ControllerContext) => Bool
  isHtmxRequest = getHeader "HX-Request" == Just "true"

  -- | Ask htmx to push a canonical URL after a fragment response.
  setHtmxPushUrl :: (?context :: ControllerContext) => Text -> IO ()
  setHtmxPushUrl url = setHeader ("HX-Push-Url", cs url)
  ```
- **Required imports:**
  ```haskell
  import IHP.ControllerPrelude
  ```
- **Files:**
  - `Application/Helper/Controller.hs`
- **Verification:** `direnv exec . typecheck`

### Slice 5.2: Profile completion gate pattern
- **Status:** [ ]
- **Strategy:** Add the `ensureProfileCompleted` pattern to `Application/Helper/Controller.hs` as a documented but optional pattern. The template's `users` table does not have `is_profile_completed`, so provide a stub that projects can fill in:
  ```haskell
  -- | Redirect to profile edit if required fields are incomplete.
  -- Customize the condition for your project's profile requirements.
  -- ensureProfileCompleted :: (?context :: ControllerContext) => IO ()
  -- ensureProfileCompleted = ...
  ```
  Add the comment only — do not add the function itself, since the schema doesn't support it yet.
- **Files:**
  - `Application/Helper/Controller.hs`
- **Verification:** `direnv exec . typecheck`

### Slice 5.3: Time parsing utilities
- **Status:** [ ]
- **Strategy:** Add generic time utilities to `Application/Helper/Controller.hs`:
  ```haskell
  import Data.Time.Format (defaultTimeLocale, parseTimeM)
  import Data.Time.LocalTime (TimeOfDay (..))

  -- | Parse a HH:MM text value into a TimeOfDay.
  parseTimeParam :: Text -> Maybe TimeOfDay
  parseTimeParam value = parseTimeM True defaultTimeLocale "%H:%M" (cs value)

  -- | True when a TimeOfDay falls on a 15-minute boundary.
  isQuarterHourTime :: TimeOfDay -> Bool
  isQuarterHourTime tod = todMin tod `mod` 15 == 0 && todSec tod == 0

  -- | Convert TimeOfDay to total minutes since midnight.
  timeOfDayToMinutes :: TimeOfDay -> Int
  timeOfDayToMinutes tod = todHour tod * 60 + todMin tod
  ```
- **Files:**
  - `Application/Helper/Controller.hs`
- **Verification:** `direnv exec . typecheck`

---

## Phase 6 — Optional: Quarter-Hour Time Picker Component

This phase is optional. Include it if the template should ship with a reusable time-picker component out of the box. Skip it if the template should stay minimal.

### Slice 6.1: Time picker Haskell helpers
- **Status:** [ ]
- **Strategy:** Add to `Application/Helper/View.hs`:
  - `timePickerModalId` constant
  - `quarterHourTimeOptions` — generates `(value, label)` pairs
  - `renderQuarterHourTimePickerModal` — the Bootstrap modal markup
  - `renderTimePickerOption` — individual option button
  - `timeOfDayToStorageValue`, `optionalTimeOfDayToStorageValue`, `storageTimeToDisplayLabel` — formatting helpers
- **Required imports:**
  ```haskell
  import Data.Time.Format (defaultTimeLocale, formatTime, parseTimeM)
  import Data.Time.LocalTime (TimeOfDay (..))
  ```
- **Files:**
  - `Application/Helper/View.hs`
- **Verification:** `direnv exec . typecheck`

### Slice 6.2: Time picker JavaScript
- **Status:** [ ]
- **Strategy:** Add `enableQuarterHourTimePicker` IIFE to `static/app.js` (after the toast host IIFE).
- **Files:**
  - `static/app.js`
- **Verification:** Visual check — picker modal renders, options respond to clicks.

### Slice 6.3: Time picker CSS
- **Status:** [ ]
- **Strategy:** Add `.time-picker-grid` and `.time-picker-option` classes to `static/app.css`.
- **Files:**
  - `static/app.css`
- **Verification:** Visual check.

### Slice 6.4: Wire time picker into Layout.hs
- **Status:** [ ]
- **Strategy:** Add `{renderQuarterHourTimePickerModal}` to `defaultLayout` in `Web/View/Layout.hs`, before the closing `</body>`.
- **Files:**
  - `Web/View/Layout.hs`
- **Verification:** `direnv exec . typecheck`

---

## Verification Checklist

After all phases are complete on `master`, verify:

1. `direnv exec . typecheck` passes
2. `direnv exec . test` passes (existing tests on master)
3. `direnv exec . lint` passes
4. `direnv exec . format` produces no diff
5. `devenv up` starts and the welcome page renders with the dark theme
6. Dialog overlay mount exists in DOM (`<div id="dialog-overlay-mount"></div>`)
7. Toast overlay renders flash messages as bottom-center toasts
8. `direnv exec . dev-start && direnv exec . dev-wait && direnv exec . dev-stop` lifecycle works
9. `direnv exec . screenshot-page --help` prints usage
10. No references to roster, staff, timesheets, leave, venue, or other domain concepts exist in master's code (grep check)

## File Inventory — What Master Gets

### New files
| File | Phase | Purpose |
|------|-------|---------|
| `static/vendor/bootstrap-5.3.8/bootstrap.min.css` | 2.1 | Vendored Bootstrap CSS |
| `static/vendor/bootstrap-5.3.8/bootstrap.bundle.min.js` | 2.1 | Vendored Bootstrap JS |
| `e2e/screenshot-page.mjs` | 1.6 | Authenticated screenshot CLI |
| `Application/AGENTS.md` | 4.2 | Schema/helper agent guide |
| `Web/Controller/AGENTS.md` | 4.3 | Controller agent guide |
| `Web/View/AGENTS.md` | 4.4 | View agent guide |
| `e2e/AGENTS.md` | 4.5 | E2E testing agent guide |

### Modified files
| File | Phases | Changes |
|------|--------|---------|
| `flake.nix` | 1.1-1.3, 1.6 | Dev lifecycle scripts, hlint fix, screenshot-page script |
| `Makefile` | 1.4 | IHP_LIB fallback resolution |
| `Config/Config.hs` | 1.5 | Trailing newline |
| `Web/View/Layout.hs` | 2.1, 2.3, 3.3 | Bootstrap 5.3.8, dark shell, header, overlay mounts, flash toasts |
| `static/app.css` | 2.2 | Dark-mode tokens, semantic classes, toast styles |
| `static/app.js` | 3.2 | Dialog overlay + toast host JS |
| `Application/Helper/View.hs` | 3.1 | Overlay config types + renderers |
| `Application/Helper/Controller.hs` | 5.1, 5.3 | HTMX helpers, time utilities |
| `AGENTS.md` | 4.1 | Dev automation docs, overlay architecture |

### Untouched on master (stay as-is)
- `Application/Schema.sql` — keep the simple `users` table
- `Web/Types.hs` — keep existing controller types (Static, Sessions, Users, Dashboard)
- `Web/Routes.hs` — no changes
- `Web/FrontController.hs` — no changes
- `Web/Controller/Prelude.hs` — no changes (do not add Conflict import)
- `Web/View/Prelude.hs` — no changes
- All domain controllers, views, tests, specs, and plans — stay on `roster` only
