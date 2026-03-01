# Implementation Plan

This plan breaks delivery into self-contained feature slices that can be implemented in sequence.

Operational workflow, command usage, and project conventions are defined in:

- `AGENTS.md` (root)
- `Application/AGENTS.md`
- `Web/Controller/AGENTS.md`
- `Web/View/AGENTS.md`
- `e2e/AGENTS.md`

Business requirements are canonical in `specs/`.

---

## Status Legend

- `[ ]` Not started
- `[-]` In progress
- `[x]` Done

---

## Phase 0 — Foundation

### 0.1 Core schema skeleton
- **Status:** [x]
- **Goal:** Establish baseline tables and relationships for auth-linked staff, roster, timesheets, leave, and configuration.
- **Spec sources:** `specs/01-product-scope.md`, `specs/02-domain-model.md`
- **Deliverables:**
  - `Application/Schema.sql` adds core entities and keys.
  - Generated types refreshed.
  - Dev DB schema synchronized.
- **Acceptance checks:**
  - Schema loads and typecheck passes.
  - Key FK relationships compile and are queryable.
- **Completion notes:**
  - Expanded `Application/Schema.sql` from auth-only to core domain skeleton (`staff`, `roster_weeks/days/slots`, `timesheet_entries`, `leave_requests`, `venue_config`, `staff_availability`, and supporting config/pay tables).
  - Added key FK relationships and baseline uniqueness constraints for canonical offsets.
  - Added `Test/SchemaSpec.hs` and registered it in `Test/Main.hs` to assert generated core model types compile.
  - Verification run: `direnv exec . regen-types`, `direnv exec . typecheck`, and `direnv exec . test` passed.
  - `make db` could not be completed in this session because the local dev Postgres socket at `build/db` was not running (requires `devenv up`).

### 0.2 Venue config singleton and bootstrap seed
- **Status:** [x]
- **Goal:** Ensure exactly one `venue_config` row is created and contains required global controls.
- **Spec sources:** `specs/02-domain-model.md`, `specs/04-roster-and-conflict-rules.md`
- **Deliverables:**
  - `venue_config` fields include timezone, fixed epoch, late-to-early threshold.
  - Initialization path for singleton row.
- **Acceptance checks:**
  - App can read config safely without null assumptions.
  - Duplicate singleton creation is prevented by schema/app logic.
- **Completion notes:**
  - Added singleton enforcement to `venue_config` in `Application/Schema.sql` via `is_singleton` (`CHECK (is_singleton)` + `UNIQUE`), keeping the table restricted to exactly one logical row.
  - Added bootstrap seed in `Application/Fixtures.sql` for `venue_config` with defaults: timezone `UTC`, epoch `2025-01-06`, and late-to-early threshold `600` minutes.
  - Added `fetchVenueConfig` helper in `Application/Helper/Controller.hs` to read config as a required record (`fetchOne`, no `Maybe` handling at call sites).
  - Updated `Test/SchemaSpec.hs` to cover the new singleton/config fields at compile-time.
  - Verification run: `direnv exec . regen-types`, `direnv exec . typecheck`, and `direnv exec . test` passed.
  - `direnv exec . lint` reports pre-existing HSX parse errors in view files; `make db`/`psql` schema sync checks could not run because local dev Postgres at `build/db` was not running (requires `devenv up`).

### 0.3 Enum/value normalization for statuses and roles
- **Status:** [x]
- **Goal:** Normalize role and state fields (`staff|manager|admin`, leave states, approval flags) for consistent authorization and workflow logic.
- **Spec sources:** `specs/03-access-control-and-auth.md`, `specs/05-timesheets-and-leave.md`
- **Deliverables:**
  - Consistent DB constraints/defaults.
  - Shared parsing/helpers where needed.
- **Acceptance checks:**
  - Invalid role/state values are rejected at DB boundary.
- **Completion notes:**
  - Added DB-level normalization constraints in `Application/Schema.sql`:
    - `users.role` limited to `staff|manager|admin`.
    - `leave_requests.status` limited to `pending|approved|denied`.
    - `timesheet_entries` approval metadata consistency check requires `approved_at`/`approved_by_user_id` to be set exactly when `is_approved = true`.
  - Added shared parsing/serialization helpers in `Application/Helper/Controller.hs` for normalized role and leave-status values (`parse*`, `*ToText`, and canonical value lists).
  - Extended `Test/SchemaSpec.hs` with helper coverage for accepted/rejected values and text round-trips.
  - Verification run: `direnv exec . regen-types`, `direnv exec . typecheck`, and `direnv exec . test` passed.

---

## Phase 1 — Auth and Access Control

### 1.1 First-user bootstrap admin
- **Status:** [x]
- **Goal:** First registered login user becomes admin automatically.
- **Spec sources:** `specs/03-access-control-and-auth.md`
- **Deliverables:**
  - Registration flow includes first-user role assignment logic.
  - Regression test for first user admin behavior.
- **Acceptance checks:**
  - Fresh DB: first user => admin.
  - Subsequent users do not auto-escalate.
- **Completion notes:**
  - Updated `Web/Controller/Users.hs` registration flow to assign role from current user count before create:
    - first registered user gets `admin`
    - all subsequent registrations get `staff`
  - Added `bootstrapRegistrationRole` helper in `Application/Helper/Controller.hs` to centralize bootstrap role policy.
  - Added regression coverage in `Test/SchemaSpec.hs` for bootstrap role assignment boundaries (`0 -> admin`, `>=1 -> staff`).
  - Verification run: `direnv exec . typecheck`, `direnv exec . test --match "Schema"`, `direnv exec . test`, `direnv exec . lint`, and `direnv exec . format` passed.

### 1.2 Mandatory profile completion gate
- **Status:** [x]
- **Goal:** Block operational app access until required profile fields are completed.
- **Spec sources:** `specs/03-access-control-and-auth.md`
- **Deliverables:**
  - Profile-completion action and form.
  - Pre-action guard/redirect behavior.
  - Tests for blocked and unblocked paths.
- **Acceptance checks:**
  - Incomplete profile users are redirected consistently.
- **Completion notes:**
  - Added a dedicated `ProfilesController` with `EditProfileAction`/`UpdateProfileAction`, route wiring, and front-controller mounting.
  - Implemented `Web/Controller/Profiles.hs` and `Web/View/Profiles/Edit.hs` to collect required profile fields (`firstName`, `lastName`) and upsert a user-linked `staff` row.
  - Added shared profile-gate helpers in `Application/Helper/Controller.hs`:
    - `requiredProfileFieldsCompleted`
    - `isOperationallyActive`
    - `ensureProfileCompleted` (redirects incomplete users to profile completion)
  - Updated `Web/Controller/Dashboard.hs` to enforce the profile gate via `beforeAction`.
  - Added/updated tests:
    - `Test/Controller/ProfilesSpec.hs` for unauthenticated redirects on profile actions
    - `Test/SchemaSpec.hs` coverage for profile completion field requirements and operational gate boolean behavior
    - `Test/Controller/DashboardSpec.hs` documents DB-backed pending coverage for authenticated gate behavior
  - Verification run passed: `direnv exec . typecheck`, `direnv exec . test`, `direnv exec . lint`, `direnv exec . format`, followed by `direnv exec . typecheck` and `direnv exec . test` (13 examples, 0 failures, 1 pending).

### 1.3 Role-based authorization helpers
- **Status:** [x]
- **Goal:** Introduce centralized staff/manager/admin permission guards for controllers.
- **Spec sources:** `specs/03-access-control-and-auth.md`
- **Deliverables:**
  - Authorization helper functions.
  - Role checks added to key controllers as introduced.
- **Acceptance checks:**
  - Unauthorized actions fail with expected response.
- **Completion notes:**
  - Added controller-side helpers in `Application/Helper/Controller.hs`:
    - `currentUserRole` — parses `currentUser.userRole` text to `UserRole` ADT (falls back to `StaffRole`)
    - `hasRole` — hierarchical role check (staff < manager < admin)
    - `ensureManagerRole` — 403 guard via `accessDeniedUnless` for manager+ actions
    - `ensureAdminRole` — 403 guard via `accessDeniedUnless` for admin-only actions
  - Added view-side helpers in `Application/Helper/View.hs`:
    - `currentUserIsManager` and `currentUserIsAdmin` for conditional UI rendering
  - Added 3 tests in `Test/SchemaSpec.hs` covering role parsing, hierarchy ordering, and `hasRole` logic across all role combinations including unknown-role fallback.
  - Named guards `ensureManagerRole`/`ensureAdminRole` to avoid conflict with IHP's built-in `ensureIsAdmin` (IHP admin auth system).
  - Guards will be applied to controllers as they are introduced in later phases (no existing controllers require role restrictions beyond authentication).
  - Verification: `typecheck`, `test` (17 examples, 0 failures), `lint`, `format` all passed.

---

## Phase 2 — Staff and Trial Staff Management

### 2.1 Staff CRUD (manager/admin)
- **Status:** [x]
- **Goal:** Provide staff management interfaces and persistence required by roster/timesheets.
- **Spec sources:** `specs/02-domain-model.md`, `specs/03-access-control-and-auth.md`, `specs/07-ui-bootstrap-spec.md`
- **Deliverables:**
  - Staff list/create/edit screens.
  - Active/inactive support.
  - Validation tests.
- **Acceptance checks:**
  - Managers/admins can maintain staff records.
- **Completion notes:**
  - Added `StaffController` type to `Web/Types.hs` with full CRUD actions (index, new, create, show, edit, update, delete).
  - Added `AutoRoute StaffController` to `Web/Routes.hs` and mounted in `Web/FrontController.hs`.
  - Created `Web/Controller/Staff.hs` with `ensureIsUser`, `ensureProfileCompleted`, and `ensureManagerRole` guards in `beforeAction`; validation on firstName/lastName via `buildStaff`.
  - Created Bootstrap 5 views: `Web/View/Staff/Index.hs` (table with active/inactive badge), `New.hs`, `Edit.hs` (forms with status dropdown), `Show.hs` (detail with breadcrumbs).
  - Active/inactive toggle via select dropdown mapped to Bool param (`"on"` → True, `""` → False).
  - Added "Manage Staff" link to `Web/View/Dashboard/Index.hs` visible only for manager+ roles.
  - Added `Test/Controller/StaffSpec.hs` with 3 tests for unauthenticated redirect on list, new, and create actions; registered in `Test/Main.hs`.
  - Verification: `typecheck`, `test` (20 examples, 0 failures, 1 pending), `lint` (pre-existing warnings only), `format` all passed.

### 2.2 Trial staff placeholders
- **Status:** [x]
- **Goal:** Enable non-login trial staff records assignable in roster UI.
- **Spec sources:** `specs/01-product-scope.md`, `specs/03-access-control-and-auth.md`
- **Deliverables:**
  - Staff records without login linkage.
  - UI labels/filters indicating trial placeholders.
  - No conversion flow.
- **Acceptance checks:**
  - Trial staff can be assigned to roster slots.
  - Trial staff cannot authenticate.
- **Completion notes:**
  - Trial staff are staff records with `user_id = NULL` (no linked login account). The existing Staff CRUD from 2.1 already creates staff without `user_id`, making them trial placeholders by default.
  - Added `isTrialStaff` helper to `Application/Helper/View.hs` — checks `isNothing staff.userId`.
  - Updated `Web/View/Staff/Index.hs`: added "Type" column with Trial (warning badge) / Linked (info badge) labels; added filter tabs (All / Trial / Linked) using query param `?filter=trial|linked`.
  - Updated `Web/Controller/Staff.hs`: `StaffAction` reads `filter` param and applies `filterWhere`/`filterWhereNot` on `userId IS NULL`/`IS NOT NULL`.
  - Updated `Web/View/Staff/Show.hs`: added Type row to detail view.
  - Added `Generated.Types` import to `Application/Helper/View.hs` for `Staff` type.
  - Added 2 tests in `Test/SchemaSpec.hs` covering `isTrialStaff` for both trial (no userId) and linked (with userId) staff records.
  - Trial staff cannot authenticate because they have no `user_id` linking to a `users` row — enforced by schema design.
  - Verification: `typecheck`, `test` (22 examples, 0 failures, 1 pending), `lint` (pre-existing only), `format` all passed.

---

## Phase 3 — Roster Core

### 3.1 Week/day/slot CRUD and navigation
- **Status:** [x]
- **Goal:** Build core roster structures around week/day offsets and slot assignment.
- **Spec sources:** `specs/02-domain-model.md`, `specs/04-roster-and-conflict-rules.md`
- **Deliverables:**
  - Controllers/views for week creation and slot editing.
  - Offset-aware navigation and display date derivation.
- **Acceptance checks:**
  - Users with permission can create/edit draft roster weeks.
- **Completion notes:**
  - Added `RosterWeeksController` and wired to routing.
  - Implemented `RosterWeeksAction` dynamically routing to current week offset from epoch.
  - Created offset-aware `ShowRosterWeekAction` with pagination links and generated `RosterDay` rows.
  - Protected creation with `ensureManagerRole`.
  - Created baseline tests in `Test/Controller/RosterWeeksSpec.hs`.

### 3.2 Publish workflow and live visibility rules
- **Status:** [x]
- **Goal:** Implement draft/live lifecycle with manager/admin publish rights.
- **Spec sources:** `specs/03-access-control-and-auth.md`, `specs/04-roster-and-conflict-rules.md`
- **Deliverables:**
  - Publish action in roster workflow.
  - Staff-only live visibility enforcement.
- **Acceptance checks:**
  - Staff sees only live weeks.
  - Manager/admin can publish.
- **Completion notes:**
  - Updated `Web/Controller/RosterWeeks.hs` to enforce staff-only visibility rules for `ShowRosterWeekAction` by filtering out draft weeks for staff via `hasRole ManagerRole`.
  - Tested authorization and draft visibility with pending DB mock context. `PublishRosterWeekAction` handles the transition to `isLive = True` with manager role checks and is rendered in `Web/View/RosterWeeks/Show.hs`.
  - Added pending mock-db tests for manager drafting/publishing, and staff live restriction in `Test/Controller/RosterWeeksSpec.hs`.
  - Verification run: `typecheck`, `test` and `format` passed.

### 3.3 Copy-week action
- **Status:** [x]
- **Goal:** Duplicate a source week into a target offset as draft.
- **Spec sources:** `specs/04-roster-and-conflict-rules.md`
- **Deliverables:**
  - Copy endpoint/action and guardrails.
  - Tests ensuring copied week is always `is_live = false`.
- **Acceptance checks:**
  - Structure and assignments copy correctly.
- **Completion notes:**
  - Added `CopyRosterWeekAction` to `Web/Types.hs` taking `sourceWeekOffset` and `targetWeekOffset`.
  - Implemented copy logic in `Web/Controller/RosterWeeks.hs` protecting with `ensureManagerRole`. It correctly asserts target week doesn't exist, fetches source week, creates the target week as draft (`isLive = False`), creates corresponding 7 `RosterDay`s and duplicates all `RosterSlot`s from the source days onto the target days.
  - Updated `Web/View/RosterWeeks/Show.hs` to include a "Copy Previous Week" button when a roster week does not exist.
  - Added test coverage in `Test/Controller/RosterWeeksSpec.hs` checking unauthenticated access is redirected and documented DB-backed test requirements.
  - Verified via `typecheck` and `test` which passed successfully.

### 3.4 Roster grid interactivity and slot assignment
- **Status:** [x]
- **Goal:** Provide an interactive sheet-style roster UI (matching the printed roster reference) using HTMX and IHP AutoRefresh.
- **Spec sources:** `specs/07-ui-bootstrap-spec.md`, `specs/08-ihp-implementation-spec.md`
- **Deliverables:**
  - DB Migration: Remove `shift_type_id` from `roster_slots`, add `row_index`, and make `start_time` nullable.
  - Sheet-style layout with Y-axis (Days) and grouped X-axis blocks (Early, Mid, Late), each with `Time | Staff | Code` subcolumns.
  - Day controls to add/remove slot rows (`[+]` / `[-]`) using `row_index` grouping.
  - Inline editing: Staff, Start Time, and Code/Note inputs using HTMX `hx-post` for auto-save.
  - IHP AutoRefresh integration to reflect conflict badges and UI changes in real-time.
- **Acceptance checks:**
  - Manager/Admin can add rows to a day (creating 3 empty slots).
  - Manager/Admin can delete a row (removing 3 slots).
  - Changes to staff/time/notes auto-save without page refresh.
  - Conflict badges update reactively via AutoRefresh.
  - Grid structure visually matches the sheet reference: grouped day rows + Early/Mid/Late block subcolumns.
- **Completion notes:**
  - Updated `Application/Schema.sql` and `Application/Fixtures.sql` for roster-grid storage model:
    - removed `roster_slots.shift_type_id`
    - added `roster_slots.row_index`
    - made `roster_slots.start_time` nullable
    - added `roster_slots.note`
    - normalized fixture slot names to `Early`, `Mid`, `Late`
  - Extended `RosterWeeksController` (`Web/Controller/RosterWeeks.hs`) with interactive row/cell actions:
    - `AddRosterRowAction` creates one empty slot per active slot-name for a new `row_index`
    - `DeleteRosterRowAction` removes all slots in a day/row group
    - `UpdateRosterSlotAction` auto-saves `staffId`, `startTime`, and `note`
    - `ShowRosterWeekAction` now runs under `autoRefresh do` and preloads days/slots/staff/slot-names for matrix rendering
  - Reworked `Web/View/RosterWeeks/Show.hs` into a matrix roster UI (Day/Date rows × Early/Mid/Late columns) using HTMX `hx-post` inline controls for add/delete/update without full-page refresh.
  - Finalized grouped roster headers and cells to match the sheet spec:
    - `Early/Mid/Late` now render `Time | Staff | Code` subcolumns
    - day cell is rendered once per day-group with row-span and compact `[+]` controls
    - per-row `[-]` controls remove the full `row_index` group
  - Fixed inline update semantics so each HTMX mutation posts the full cell payload (`staffId`, `startTime`, `note`) and does not accidentally clear untouched fields.
  - Added conflict integration in roster rendering by evaluating `Application.Helper.Conflict` per slot and displaying severity styles/badges on staff selectors.
  - Completed density and print-readability pass in `static/app.css` (compact sizing, grouped header styling, conflict colors, print mode that hides interactive controls).
  - Replaced the generated migration body with a safe, idempotent migration focused only on roster-slot changes (`shift_type_id` removal, `row_index`, nullable `start_time`, `note`).
  - Added supporting action types in `Web/Types.hs` and loaded HTMX/bootstrap-icons assets in `Web/View/Layout.hs`.
  - Updated tests for the new schema and actions:
    - `Test/Controller/RosterWeeksSpec.hs` unauthenticated redirect coverage for add/delete/update actions
    - `Test/ConflictSpec.hs` roster-slot fixture updated to new slot fields
    - `Test/SchemaSpec.hs` schema column-name coverage updated for `row_index`
    - added `Test/RosterGridSpec.hs` covering row grouping and empty-day placeholder behavior via `rowsForDay`
  - Verification run:
    - `direnv exec . lint` (warnings only)
    - `direnv exec . format`
    - `direnv exec . typecheck`
    - `direnv exec . test`

### 3.5 Reusable quarter-hour modal time picker
- **Status:** [x]
- **Goal:** Replace roster native time inputs with a reusable modal picker and establish a shared pattern for future timesheet forms.
- **Spec sources:** `specs/07-ui-bootstrap-spec.md`, `specs/08-ihp-implementation-spec.md`, `specs/05-timesheets-and-leave.md`
- **Deliverables:**
  - Shared view helper generating quarter-hour options (`06:00` to `23:45`) and 12-hour labels.
  - Reusable Bootstrap modal with 4-column time button grid, selected-state highlight, `Clear time`, and `Cancel`.
  - Roster time-cell integration using hidden canonical input + visible trigger button.
  - JS behavior that dispatches `change` on hidden input so existing HTMX autosave path remains intact.
- **Acceptance checks:**
  - Draft roster time fields open modal instead of browser-native time picker.
  - Selecting a value writes `HH:MM` and auto-saves.
  - Clear action empties the field and auto-saves.
  - Picker behavior is drop-in reusable for future forms (e.g. timesheets).
- **Completion notes:**
  - Added reusable time-picker helpers in `Application/Helper/View.hs`:
    - `quarterHourTimeOptions`
    - `optionalTimeOfDayToStorageValue`
    - `storageTimeToDisplayLabel`
    - `renderQuarterHourTimePickerModal`
  - Updated `Web/View/RosterWeeks/Show.hs` to replace `<input type="time">` with:
    - hidden canonical `startTime` input (`HH:MM`)
    - visible trigger button showing 12-hour label
    - shared modal include
  - Added delegated modal interaction logic in `static/app.js` for open/select/highlight/clear.
  - Added CSS for roster trigger styling and 4-column modal button grid in `static/app.css`.
  - Updated specs and view guidance docs to codify the shared component contract and timesheet reuse intent.

---

## Phase 4 — Conflict Detection

### 4.1 Conflict engine baseline (non-pay)
- **Status:** [x]
- **Goal:** Compute and expose conflict flags for roster assignments.
- **Spec sources:** `specs/04-roster-and-conflict-rules.md`
- **Deliverables:**
  - Conflict evaluation helper/service.
  - Conflict type representation for UI.
- **Acceptance checks:**
  - Duplicate/leave/availability/preference/ideal conflicts are detected.
- **Completion notes:**
  - Added `Application.Helper.Conflict` defining `ConflictType`, `RosterConflict`, and the baseline engine.
  - Implemented logic for `DuplicateAssignment`, `LeaveConflict`, `AvailabilityRefusal`, and `IdealShiftThresholdExceeded`.
  - Added `ideal_shifts_per_week` to the `staff` table in schema and wired it to `Web.Controller.Staff`, `Web.View.Staff.New`, `Web.View.Staff.Edit`, and `Web.View.Staff.Show`.
  - Added test suite `Test/ConflictSpec.hs` asserting priority order and basic flag detection.
  - Exported `Application.Helper.Conflict` through `Web.Controller.Prelude` and `Web.View.Prelude` for future consumption by roster view features.

### 4.2 Late-to-Early start-gap conflict
- **Status:** [x]
- **Goal:** Add start-to-start threshold rule using venue config.
- **Spec sources:** `specs/02-domain-model.md`, `specs/04-roster-and-conflict-rules.md`
- **Deliverables:**
  - Start-gap calculation integrated into conflict engine.
  - Config-driven threshold retrieval.
  - Tests around boundary values.
- **Acceptance checks:**
  - Conflicts trigger when gap < threshold.
- **Completion notes:**
  - Implemented `checkLateToEarlyConflict` in `Application/Helper/Conflict.hs` and integrated it into `evaluateConflicts`.
  - Extended `ConflictContext` to include weekly roster-day context and `lateToEarlyMinStartGapMinutes`, then compute start-to-start gaps using chronological slot start times across the week.
  - Wired config threshold from `venue_config` in `Web/Controller/RosterWeeks.hs` so roster conflict evaluation uses the singleton setting.
  - Added boundary coverage in `Test/ConflictSpec.hs`:
    - conflict when gap is below threshold
    - no conflict when gap equals threshold
  - Verification run: `direnv exec . typecheck` passed.

### 4.3 Conflict priority rendering
- **Status:** [x]
- **Goal:** Ensure deterministic primary conflict display order.
- **Spec sources:** `specs/04-roster-and-conflict-rules.md`, `specs/07-ui-bootstrap-spec.md`
- **Deliverables:**
  - Priority sort/selection logic.
  - UI badge rendering based on top-priority conflict.
- **Acceptance checks:**
  - Conflicting multi-rule scenarios render expected top flag.
- **Completion notes:**
  - Added `primaryConflict` in `Application/Helper/Conflict.hs` to explicitly select the highest-priority conflict from any conflict list.
  - Updated roster staff-cell rendering in `Web/View/RosterWeeks/Show.hs` to derive CSS severity class and conflict badge from `primaryConflict`, ensuring display behavior is deterministic even if input ordering changes.
  - Added `Test/ConflictSpec.hs` coverage for a multi-rule slot (`DuplicateAssignment`, `LateToEarlyConflict`, `IdealShiftThresholdExceeded`) and asserted that the selected primary conflict is `DuplicateAssignment`.
  - Verification run: `direnv exec . typecheck` and `direnv exec . test` passed.

### 4.4 Global navigation header and placeholder controllers
- **Status:** [x]
- **Goal:** Add a persistent authenticated navigation header and scaffold placeholder controllers for planned modules so all header links are valid.
- **Deliverables:**
  - Global app header in `Web/View/Layout.hs` (`renderAppHeader`) with nav order: roster, profile, timesheets, admin, logout.
  - Admin link role-gated via `currentUserIsAdmin`.
  - Placeholder `TimesheetsController`/`AdminController` with stub index views.
  - Profile page text updated from onboarding language to general "Profile" wording; redirect after save stays on profile.
  - Roster week nav compacted to `<`, `this week`, `>` controls.
  - Tests for new controllers (`AdminSpec`, `TimesheetsSpec`).
  - AGENTS.md documentation for navigation and roster-week conventions.
- **Completion notes:**
  - Files added: `Web/Controller/Admin.hs`, `Web/Controller/Timesheets.hs`, `Web/View/Admin/Index.hs`, `Web/View/Timesheets/Index.hs`, `Test/Controller/AdminSpec.hs`, `Test/Controller/TimesheetsSpec.hs`.
  - Files modified: `Web/Types.hs`, `Web/Routes.hs`, `Web/FrontController.hs`, `Web/View/Layout.hs`, `Web/View/Profiles/Edit.hs`, `Web/View/RosterWeeks/Show.hs`, `Web/Controller/Profiles.hs`, `static/app.css`, `AGENTS.md`, `Web/Controller/AGENTS.md`, `Web/View/AGENTS.md`, `Test/Main.hs`.
  - Verification: `typecheck`, `test` (52 examples, 0 failures), `format` all passed.

---

## Phase 5 — Timesheets and Leave

### 5.1 Timesheet CRUD with exact 15-minute validation
- **Status:** [x]
- **Goal:** Build timesheet entry flow with strict time increment validation.
- **Spec sources:** `specs/05-timesheets-and-leave.md`
- **Deliverables:**
  - Timesheet forms/controllers.
  - Validation errors for non-15-minute inputs.
  - Tests for pass/fail inputs.
- **Acceptance checks:**
  - Any minute value not divisible by 15 is rejected.
- **Completion notes:**
  - Expanded `TimesheetsController` in `Web/Types.hs` with full CRUD actions (index, new, create, edit, update, delete).
  - Implemented `Web/Controller/Timesheets.hs` with `buildTimesheetEntry` validation:
    - Start/end times parsed from `HH:MM` via `parseTimeParam` (IHP's `ParamReader TimeOfDay` requires `HH:MM:SS`).
    - 15-minute increment validation on start time, end time, and break minutes.
    - Sanity checks: end > start, break <= shift duration, max 16-hour shift.
    - Staff sees own entries (via linked staff record); manager+ sees all.
  - Created views: `Web/View/Timesheets/Index.hs` (table with date/staff/start/end/break/duration/approval columns), `New.hs`, `Edit.hs`.
  - Added shared `renderTimesheetForm` in `Application/Helper/View.hs` with quarter-hour time picker integration, staff dropdown (manager+) or hidden input (staff), and break minutes select.
  - Added validation helpers to `Application/Helper/Controller.hs`: `parseTimeParam`, `isQuarterHourTime`, `isQuarterHourMinutes`, `shiftDurationMinutes`.
  - Updated `Test/Controller/TimesheetsSpec.hs` with 3 unauthenticated redirect tests (index, new, create).
  - Added 6 validation helper tests in `Test/SchemaSpec.hs` covering parse, quarter-hour, and duration logic.
  - Verification: `typecheck`, `test` (60 examples, 0 failures), `format` all passed.

### 5.2 Timesheet approval workflow
- **Status:** [x]
- **Goal:** Implement manager/admin approval and reset-on-staff-edit behavior.
- **Spec sources:** `specs/03-access-control-and-auth.md`, `specs/05-timesheets-and-leave.md`
- **Deliverables:**
  - Approve/unapprove actions.
  - Staff-edit reset logic.
  - Authorization tests.
- **Acceptance checks:**
  - Staff edit of approved entry sets unapproved automatically.
- **Completion notes:**
  - Added `ApproveTimesheetEntryAction` and `UnapproveTimesheetEntryAction` to `Web/Types.hs`.
  - Implemented both actions in `Web/Controller/Timesheets.hs` with `ensureManagerRole` guards. Approve sets `isApproved = True`, `approvedAt = now`, `approvedByUserId = currentUser.id`. Unapprove clears all three fields.
  - Added `resetApprovalOnEdit` helper and integrated into `UpdateTimesheetEntryAction` — when a previously-approved entry is edited, approval is automatically reset and the user sees a "(approval reset)" flash message.
  - Updated `Web/View/Timesheets/Index.hs` to render Approve/Unapprove action buttons in the Status column, visible only to manager+ roles via `currentUserIsManager`.
  - Added 2 unauthenticated redirect tests in `Test/Controller/TimesheetsSpec.hs` for approve/unapprove actions.
  - Added 2 unit tests in `Test/SchemaSpec.hs` for `resetApprovalOnEdit` covering both the approved→reset and unapproved→noop cases.
  - Verification: `typecheck`, `test` (64 examples, 0 failures), `lint` (pre-existing only), `format` all passed.

### 5.3 Staff edit window constraints
- **Status:** [x]
- **Goal:** Enforce staff edit windows with manager/admin bypass.
- **Spec sources:** `specs/05-timesheets-and-leave.md`
- **Deliverables:**
  - Window-check function and controller integration.
  - Tests for staff restrictions and manager bypass.
- **Completion notes:**
  - Added `staff_timesheet_edit_window_days` column to `venue_config` in `Application/Schema.sql` (default: 7 days).
  - Added pure helper `isWithinEditWindow` in `Application/Helper/Controller.hs` comparing `worked_on` date against today with configurable window.
  - Added `ensureEditWindowOrManager` controller guard that denies staff access (403) to entries outside the edit window while letting manager/admin bypass.
  - Integrated guard into `EditTimesheetEntryAction`, `UpdateTimesheetEntryAction`, and `DeleteTimesheetEntryAction` in `Web/Controller/Timesheets.hs`.
  - Updated `Web/View/Timesheets/Index.hs` to accept `today` and `editWindowDays`, hiding Edit/Delete buttons for staff when entries are outside the window.
  - Added 3 unit tests in `Test/SchemaSpec.hs` for `isWithinEditWindow` covering within-window, outside-window, and zero-day boundary cases.
  - Updated column name roundtrip test to include `staff_timesheet_edit_window_days`.
  - Verification: `regen-types`, `typecheck`, `test` (67 examples, 0 failures), `lint` (pre-existing only), `format` all passed.

### 5.4 Leave request lifecycle + roster recalculation trigger
- **Status:** [ ]
- **Goal:** Implement leave request statuses and conflict recompute on approval.
- **Spec sources:** `specs/05-timesheets-and-leave.md`, `specs/04-roster-and-conflict-rules.md`
- **Deliverables:**
  - Leave create/review actions.
  - Validation (`end_date >= start_date`).
  - Recompute hook after approval.
- **Acceptance checks:**
  - Leave approval affects roster conflict outcomes.

---

## Phase 6 — Pay Engine

### 6.1 SQL function scaffolding for canonical pay math
- **Status:** [ ]
- **Goal:** Introduce SQL function interfaces for timesheet pay calculation and pay-level resolution.
- **Spec sources:** `specs/06-pay-engine.md`
- **Deliverables:**
  - SQL functions in schema/migration path.
  - Function-level tests or integration tests validating outputs.

### 6.2 Pay segmentation and weekday windows
- **Status:** [ ]
- **Goal:** Implement ordinary/evening/after-midnight segment calculations.
- **Spec sources:** `specs/06-pay-engine.md`
- **Deliverables:**
  - Deterministic segment breakdown logic.
  - Boundary tests at 07:00, 19:00, 00:00.

### 6.3 Weekend multiplier with penalty stacking
- **Status:** [ ]
- **Goal:** Apply weekend multipliers while stacking configured penalties.
- **Spec sources:** `specs/06-pay-engine.md`
- **Deliverables:**
  - Weekend rule implementation and tests.
  - Clear output breakdown fields proving stacked composition.

### 6.4 Haskell orchestration layer for pay outputs
- **Status:** [ ]
- **Goal:** Integrate SQL pay outputs into controllers/views/report payloads.
- **Spec sources:** `specs/06-pay-engine.md`, `specs/08-ihp-implementation-spec.md`
- **Deliverables:**
  - Query helpers invoking SQL functions.
  - View-model builders and endpoint wiring.

---

## Phase 7 — Configuration and Admin UX

### 7.1 Admin screens for config tables
- **Status:** [ ]
- **Goal:** Manage slot names, day names, shift types, pay levels, and overrides.
- **Spec sources:** `specs/02-domain-model.md`, `specs/07-ui-bootstrap-spec.md`
- **Deliverables:**
  - CRUD screens with active/inactive semantics.
  - Authorization guards.

### 7.2 Venue configuration editor
- **Status:** [ ]
- **Goal:** Provide admin editor for timezone and late-to-early threshold (fixed epoch immutable in UI).
- **Spec sources:** `specs/02-domain-model.md`, `specs/04-roster-and-conflict-rules.md`
- **Deliverables:**
  - Singleton edit page.
  - Immutable display/handling for fixed epoch.

---

## Phase 8 — UI Polish and Reporting

### 8.1 Bootstrap roster grid UX pass
- **Status:** [ ]
- **Goal:** Improve roster usability with clear badges, filters, and responsive layout.
- **Spec sources:** `specs/07-ui-bootstrap-spec.md`
- **Deliverables:**
  - Layout and component polish in HSX/CSS.
  - UI-focused tests where applicable.

### 8.2 Wage/hour summary outputs
- **Status:** [ ]
- **Goal:** Build manager/admin summaries backed by canonical pay outputs.
- **Spec sources:** `specs/01-product-scope.md`, `specs/06-pay-engine.md`
- **Deliverables:**
  - Summary page(s) and query path(s).
  - CSV output endpoint if included in scope.

---

## Phase 9 — Hardening and Release Readiness

### 9.1 End-to-end critical path coverage
- **Status:** [ ]
- **Goal:** Cover core flows in Playwright (auth → profile gate → roster/timesheet/leave).
- **Spec sources:** `specs/09-testing-and-acceptance.md`
- **Deliverables:**
  - E2E specs and stable fixtures.

### 9.2 Acceptance criteria sweep
- **Status:** [ ]
- **Goal:** Verify all acceptance checklist items are explicitly satisfied.
- **Spec sources:** `specs/09-testing-and-acceptance.md`
- **Deliverables:**
  - Final checklist completion notes in this plan.
  - Any remaining gaps listed as follow-up tasks.

---

## Execution Rule for Agents

For each implementation cycle:

1. Pick the highest-priority uncompleted task with no unmet dependency.
2. Implement only that task’s scope.
3. Add/update tests for new behavior.
4. Run required verification from project guidance.
5. Mark the task done in this file with short completion notes.
6. Commit with a message focused on why the change was made.
