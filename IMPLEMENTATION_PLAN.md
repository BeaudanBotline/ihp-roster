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

## Current Direction

The current implementation direction is:

- local, founder-managed rollout
- small number of venues
- standardised multi-tenant SaaS
- no public self-serve tenant creation in the near term

This means the next implementation priority is not broader feature breadth. It is the SaaS pivot work required to avoid locking the product into single-tenant/internal-tool assumptions.

Related canonical specs:

- `specs/08-ihp-implementation-spec.md`
- `specs/10-au-saas-security-privacy-compliance/03-roadmap-and-priorities.md`
- `specs/10-au-saas-security-privacy-compliance/06-engineering-backlog.md`

---

## Status Legend

- `[ ]` Not started
- `[-]` In progress
- `[x]` Done

---

## Phase A — SaaS Pivot Foundations

### A.1 Tenant schema and membership model
- **Status:** [ ]
- **Goal:** Introduce tenant ownership before any further product expansion.
- **Spec sources:** `specs/01-product-scope.md`, `specs/02-domain-model.md`, `specs/10-au-saas-security-privacy-compliance/06-engineering-backlog.md`
- **Deliverables:**
  - Add `tenants` and `tenant_memberships` to `Application/Schema.sql`.
  - Add `tenant_id` to tenant-owned business records.
  - Add required FKs and composite indexes for common tenant-scoped queries.
  - Refresh generated types.
- **Acceptance checks:**
  - Tenant-owned core records compile with tenant linkage.
  - Common access paths have explicit tenant indexes.
  - Schema and generated types remain synchronized.
- **Implementation notes:**
  - This is the highest-priority architectural change because it is expensive to retrofit after real customer data exists.
  - Prefer explicit tenant ownership in the schema over controller-only conventions.

### A.2 Current tenant resolution and tenant-scoped auth helpers
- **Status:** [ ]
- **Goal:** Ensure every authenticated request operates inside an explicit tenant context.
- **Spec sources:** `specs/03-access-control-and-auth.md`, `specs/08-ihp-implementation-spec.md`, `specs/10-au-saas-security-privacy-compliance/06-engineering-backlog.md`
- **Deliverables:**
  - Add current-tenant and current-membership helpers in shared controller code.
  - Resolve tenant context after login.
  - Add tenant-scoped role checks.
- **Acceptance checks:**
  - Authenticated controller actions can resolve tenant context without ad hoc query logic.
  - Role checks no longer rely on global user-role assumptions alone.
  - Cross-tenant access is denied by server-side guards.
- **Implementation notes:**
  - For the first few venues, a simple single-tenant-per-user assumption is acceptable if documented cleanly.

### A.3 Remove bootstrap-admin and public-signup assumptions
- **Status:** [ ]
- **Goal:** Replace internal-tool bootstrap logic with managed-service tenant bootstrap.
- **Spec sources:** `specs/03-access-control-and-auth.md`, `specs/10-au-saas-security-privacy-compliance/03-roadmap-and-priorities.md`, `specs/10-au-saas-security-privacy-compliance/06-engineering-backlog.md`
- **Deliverables:**
  - Remove or disable public self-registration as the default commercial path.
  - Remove first-user-admin bootstrap logic from registration.
  - Introduce founder-managed tenant bootstrap and owner/admin invitation flow.
- **Acceptance checks:**
  - No fresh deployment grants privileged tenant access through public signup.
  - Initial tenant owner/admin creation is explicit and controlled.
  - Documentation and tests reflect the new bootstrap flow.
- **Implementation notes:**
  - This supersedes the earlier first-user-bootstrap-admin product decision.

### A.4 Tenant-scope all core business queries
- **Status:** [ ]
- **Goal:** Remove global-data assumptions from controllers and helpers.
- **Spec sources:** `specs/02-domain-model.md`, `specs/08-ihp-implementation-spec.md`, `specs/10-au-saas-security-privacy-compliance/06-engineering-backlog.md`
- **Deliverables:**
  - Add tenant filters to roster, timesheet, leave, profile and staff queries.
  - Refactor singleton config assumptions where tenant ownership is required.
  - Add helper functions for common tenant-scoped query patterns.
- **Acceptance checks:**
  - No authenticated business flow can read or write another tenant’s data.
  - Tenant-scoped tests exist for roster, leave and timesheet flows.
- **Implementation notes:**
  - This step should land immediately after tenant context is available so the codebase does not end up half-scoped.

### A.5 Audit-event infrastructure for sensitive actions
- **Status:** [ ]
- **Goal:** Add durable auditability before exports and broader commercial use.
- **Spec sources:** `specs/02-domain-model.md`, `specs/08-ihp-implementation-spec.md`, `specs/10-au-saas-security-privacy-compliance/06-engineering-backlog.md`
- **Deliverables:**
  - Add `audit_events` schema.
  - Add shared audit write helper/service.
  - Emit events for approvals, role changes, exports and support-sensitive actions.
- **Acceptance checks:**
  - Sensitive actions create attributable audit records with tenant and actor information.
  - Audit writes participate in the same transaction as business actions where feasible.

### A.6 Correction-safe timesheets and leave history
- **Status:** [ ]
- **Goal:** Replace destructive employment-record behavior with provenance-preserving flows.
- **Spec sources:** `specs/05-timesheets-and-leave.md`, `specs/10-au-saas-security-privacy-compliance/01-regulatory-baseline.md`, `specs/10-au-saas-security-privacy-compliance/06-engineering-backlog.md`
- **Deliverables:**
  - Choose and implement a correction-safe model for timesheets.
  - Add leave status history or equivalent provenance model.
  - Update UI and tests for corrected/superseded record behavior.
- **Acceptance checks:**
  - Payroll-adjacent changes are not silently destructive.
  - Approval and correction history remain attributable and test-covered.

### A.7 Export job foundations
- **Status:** [ ]
- **Goal:** Treat exports as controlled disclosures before exposing them to customers.
- **Spec sources:** `specs/10-au-saas-security-privacy-compliance/04-accountant-exports.md`, `specs/10-au-saas-security-privacy-compliance/06-engineering-backlog.md`
- **Deliverables:**
  - Add `export_jobs` schema.
  - Add export service abstraction and scoped export metadata.
  - Add audit coverage for export generation and download.
- **Acceptance checks:**
  - Exports are attributable to tenant, actor and scope.
  - Export lifecycle is explicit rather than ad hoc controller output.

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
  - **Superseded by current direction:** This slice reflected the earlier internal-tool model and should now be removed/replaced by Phase A.3 managed tenant bootstrap.

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

### 2.1 Staff management migration into roster workflow
- **Status:** [-]
- **Goal:** Move staff management from a standalone CRUD section into the roster workflow while preserving manager/admin edit capability.
- **Spec sources:** `specs/02-domain-model.md`, `specs/03-access-control-and-auth.md`, `specs/07-ui-bootstrap-spec.md`
- **Deliverables:**
  - Remove dashboard-driven staff-management entrypoints.
  - Remove the standalone staff management page from the intended workflow.
  - Re-surface staff editing via the roster-side staff panel modal.
  - Preserve active/inactive support and validation behavior in the modal workflow.
- **Acceptance checks:**
  - Managers/admins can edit staff from the roster page without relying on a dedicated staff index page.
- **Completion notes:**
  - Current codebase includes a standalone `StaffController`/`StaffAction` CRUD workflow and earlier dashboard-driven discoverability.
  - Target workflow removes the dashboard concept and removes staff management as a dedicated primary page.
  - Existing staff edit logic can be reused behind a roster-launched modal, but navigation, controller usage, and documentation need to be simplified around the roster page as the management surface.

### 2.1a Remove dashboard surface and routing
- **Status:** [x]
- **Goal:** Delete the dashboard concept from code and route all home-page behavior through roster weeks.
- **Dependencies:** none
- **Deliverables:**
  - Remove `DashboardController` types/routes/mounts/views/tests.
  - Replace dashboard breadcrumbs/links with roster-first navigation.
  - Remove any residual dashboard references from docs and layout usage.
- **Acceptance checks:**
  - No runtime route or view references remain to `DashboardAction`.
  - Post-login navigation still lands on roster weeks.
- **Completion notes:**
  - Removed `DashboardController` from `Web/Types.hs`, `Web/Routes.hs`, and `Web/FrontController.hs`, and deleted the obsolete dashboard controller/view files.
  - Removed `Test/Controller/DashboardSpec.hs` and its `Test/Main.hs` registration, since the dashboard route no longer exists.
  - Updated roster/staff breadcrumbs to use `RosterWeeksAction` instead of `DashboardAction`, and removed the roster-page dashboard breadcrumb entirely.
  - Added a regression check in `Test/Controller/SessionsSpec.hs` to pin successful login redirects to `RosterWeeksAction`.
  - Verification run: `direnv exec . typecheck`, `direnv exec . test`, `direnv exec . format`, and `direnv exec . typecheck` passed. `direnv exec . lint` reported only pre-existing hints in `Web/Controller/Timesheets.hs` and `Web/View/Timesheets/*.hs`.

### 2.1b Retire standalone staff page from active workflow
- **Status:** [x]
- **Goal:** Remove the dedicated staff-management page from the intended user flow while preserving reusable edit logic.
- **Dependencies:** 2.1a
- **Deliverables:**
  - Remove discoverability/navigation for standalone staff CRUD.
  - Audit whether `StaffController` is deleted entirely or retained only as internal reusable modal support.
  - Remove docs/tests that treat `StaffAction` as a primary management surface.
- **Acceptance checks:**
  - Managers/admins are no longer directed to a dedicated "manage staff" page.
  - Remaining staff-edit capabilities are clearly attached to the roster workflow only.
- **Completion notes:**
  - Reduced `StaffController` to `EditStaffAction` and `UpdateStaffAction` only in `Web/Types.hs` and `Web/Controller/Staff.hs`, keeping staff editing available as reusable support instead of a standalone CRUD section.
  - Deleted the dedicated standalone staff index/new/show views (`Web/View/Staff/Index.hs`, `New.hs`, `Show.hs`) and removed controller code for list/create/show/delete actions.
  - Updated the remaining edit view to breadcrumb/cancel back to `RosterWeeksAction`, keeping the surviving staff workflow anchored to the roster page.
  - Reworked `Test/Controller/StaffSpec.hs` so coverage is on the retained edit/update entrypoints rather than the removed `StaffAction` list page.
  - Verification run: `direnv exec . typecheck`, `direnv exec . test`, `direnv exec . format`, and `direnv exec . typecheck` passed. `direnv exec . lint` still reports only pre-existing hints in the Timesheets files.

### 2.1c Roster-launched staff edit modal
- **Status:** [x]
- **Goal:** Reuse staff edit functionality inside a manager/admin modal launched from the roster page.
- **Dependencies:** 2.1b, 3.4b
- **Deliverables:**
  - Read/write modal launched from roster-side staff list.
  - Fields equivalent to the current staff edit flow, including active/inactive toggle.
  - Validation and save behavior for manager/admin.
- **Acceptance checks:**
  - Manager/admin can edit staff without leaving the roster page.
  - Existing active/inactive and core identity fields save correctly.
- **Completion notes:**
  - Switched `EditStaffAction`/`UpdateStaffAction` to the IHP modal flow in `Web/Controller/Staff.hs` using `setModal` + `jumpToAction ShowRosterWeekAction`, carrying `weekOffset` through query/form params.
  - Converted `Web/View/Staff/Edit.hs` into a modal view and added `renderStaffEditModal` in `Application/Helper/View.hs` so cancel/close returns to the same roster week.
  - Added a manager/admin roster-side staff panel to `Web/View/RosterWeeks/Show.hs` and `Web/Controller/RosterWeeks.hs`, showing active linked staff with assigned-shift count, ideal shifts, user role, and an `Edit` launcher that opens the modal over the roster page.
  - Added helper/test coverage for roster-panel filtering in `Application/Helper/View.hs` and `Test/SchemaSpec.hs`, and updated `Test/Controller/StaffSpec.hs` to cover the weekOffset-backed edit/update entrypoints.
  - Follow-up design decision: this server-roundtrip modal approach is now considered transitional because it rerenders the roster page and introduces noticeable local latency when opening modals.

### 2.1d Reusable HTMX modal system for roster workflows
- **Status:** [x]
- **Goal:** Replace roster-side `setModal` page-jump workflows with a reusable HTMX modal pattern that swaps only modal HTML into a shared mount.
- **Dependencies:** 2.1c
- **Deliverables:**
  - A persistent modal mount in `Web/View/Layout.hs`.
  - Shared modal fragment helper(s) in `Application/Helper/View.hs`.
  - Staff edit flow migrated to HTMX GET/submit fragment responses.
  - Shared JS to open, close, clear, and restore focus for arbitrary modal fragments.
- **Acceptance checks:**
  - Clicking `Edit` in the roster staff panel does not trigger a full-page rerender or Turbolinks visit.
  - Validation errors rerender inside the modal only.
  - Successful submit updates the relevant roster/staff fragments and closes the modal without a full-page navigation.
  - The same modal infrastructure can be reused by future create/edit/confirm/picker workflows.
- **Implementation notes:**
  - Keep `weekOffset` or equivalent return-context params in HTMX URLs/forms so the modal stays anchored to the currently viewed roster week.
  - Use `respondHtml` for fragment responses and favor minimal fragment updates (`#roster-content` or OOB row fragments) after successful submits.
  - Treat full-page controller routes as fallback only; the primary roster UX should use HTMX modal fragments.
  - Documented the roster modal pattern in `Web/Controller/AGENTS.md` and `Web/View/AGENTS.md`.
  - Added reusable HTMX modal helpers in `Application/Helper/View.hs` plus shared modal-mount lifecycle JS in `static/app.js` for open/close/escape/backdrop/focus behavior.
  - Migrated `Web/Controller/Staff.hs` and `Web/View/Staff/Edit.hs` to HTMX fragment GET/POST handling with inline validation rendering and roster-content OOB refreshes on success.
  - Updated `Web/View/RosterWeeks/Show.hs` and `Web/Controller/RosterWeeks.hs` so the roster staff panel launches the modal without Turbolinks navigation and accepts OOB roster refresh responses.
  - Added focused browser coverage in `e2e/roster-staff-modal.spec.ts` for modal launch, HTMX validation-fragment response, and successful in-place save.
  - Verification run: `direnv exec . typecheck`, `direnv exec . test`, and `direnv exec . e2e e2e/roster-staff-modal.spec.ts` passed. `direnv exec . lint` still reports only pre-existing Timesheets hints.

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

### 3.1 Universal week navigation and manager auto-create
- **Status:** [-]
- **Goal:** Make roster week navigation universal while auto-creating missing weeks for manager/admin on view.
- **Spec sources:** `specs/02-domain-model.md`, `specs/04-roster-and-conflict-rules.md`
- **Deliverables:**
  - Offset-aware navigation and display date derivation.
  - Manager/Admin auto-create on view for missing weeks.
  - Staff browsing across all week offsets with unpublished-week placeholder messaging.
- **Acceptance checks:**
  - Manager/Admin can navigate to any week and immediately edit it without an explicit create action.
  - Staff can navigate to any week and see either live content or a not-published-yet message.
- **Completion notes:**
  - Current code uses an explicit "create draft roster" workflow when a week does not exist.
  - Target workflow removes explicit creation as a user-facing concept.
  - Implementation should shift missing-week handling from a create CTA to automatic week/day creation when a manager/admin views that offset.
  - Staff users should no longer be blocked from navigating to empty/unpublished offsets; instead they receive a non-editable not-published-yet state.

### 3.1a Auto-create roster weeks for manager/admin on view
- **Status:** [ ]
- **Goal:** Convert missing-week access from explicit creation to automatic draft week creation for manager/admin viewers.
- **Dependencies:** none
- **Deliverables:**
  - `ShowRosterWeekAction` path creates missing `roster_weeks`/`roster_days` for manager/admin when viewed.
  - Remove create-draft CTA and explicit create action from the user workflow.
  - Keep creation side effects out of staff views.
- **Acceptance checks:**
  - Visiting any week as manager/admin yields an editable roster surface immediately.
  - No "create draft roster" UI remains.

### 3.1b Staff unpublished-week placeholder state
- **Status:** [ ]
- **Goal:** Let staff browse all weeks while showing an explicit unpublished message for non-live weeks.
- **Dependencies:** 3.1a
- **Deliverables:**
  - Staff can navigate past/future offsets without access errors.
  - Non-live weeks render a "not published yet" message instead of editable roster content.
- **Acceptance checks:**
  - Staff can move between week offsets freely.
  - Staff never see draft content.

### 3.2 Roster settings and live visibility controls
- **Status:** [-]
- **Goal:** Move live/draft control into roster settings while retaining staff live-only visibility.
- **Spec sources:** `specs/03-access-control-and-auth.md`, `specs/04-roster-and-conflict-rules.md`
- **Deliverables:**
  - Roster settings control for live/draft state.
  - Staff-only live visibility enforcement.
  - Unpublished-week message state for staff.
- **Acceptance checks:**
  - Staff sees only live weeks.
  - Manager/Admin can toggle live/draft from the roster settings bar.
- **Completion notes:**
  - Current code exposes publish controls as a dedicated roster action.
  - Target workflow keeps the `is_live` concept but moves it into the new collapsible settings bar on the roster page.
  - Staff behavior remains live-only, but the user-facing state changes from hidden content to an explicit unpublished-week message.

### 3.2a Add persistent per-user roster view settings
- **Status:** [ ]
- **Goal:** Persist manager/admin roster display preferences on the server side.
- **Dependencies:** none
- **Deliverables:**
  - DB-backed per-user settings store for roster page preferences.
  - Initial setting: `show staff list` defaulting to `true` for manager/admin.
- **Acceptance checks:**
  - Setting survives refresh, logout/login, and device/browser changes.

### 3.2b Add collapsible roster settings bar
- **Status:** [ ]
- **Goal:** Introduce the manager/admin roster settings surface at the top of the roster page.
- **Dependencies:** 3.2a
- **Deliverables:**
  - Collapsible settings bar above roster content.
  - `show staff list` toggle.
  - live/draft checkbox visible only to manager/admin.
  - Persist contained settings values; do not persist open/closed state.
- **Acceptance checks:**
  - Settings are only visible to manager/admin.
  - Toggling values updates persisted state.
  - Staff does not see these controls.

### 3.3 Import overwrite workflow
- **Status:** [-]
- **Goal:** Convert copy-week into destructive import-overwrite semantics.
- **Spec sources:** `specs/04-roster-and-conflict-rules.md`
- **Deliverables:**
  - Import action with explicit confirmation.
  - Overwrite semantics that make the target identical to the source.
  - Tests covering overwrite behavior for empty and populated targets.
- **Acceptance checks:**
  - Import makes the target week identical to the source week.
  - Import always confirms before destructive overwrite.
- **Completion notes:**
  - Current code treats copy as a create-only operation and blocks when the target already exists.
  - Target workflow replaces this with import/overwrite semantics regardless of whether the target week is currently empty or populated.
  - The import path should preserve source week identity fully at the roster-data level and require confirmation every time.

### 3.3a Replace copy semantics with overwrite import
- **Status:** [ ]
- **Goal:** Make import replace the target roster week contents completely, whether empty or populated.
- **Dependencies:** 3.1a
- **Deliverables:**
  - Import action that deletes/replaces target roster content.
  - Source roster copied exactly into target week.
  - Future-safe handling so week-level metadata can also be synchronized if introduced later.
- **Acceptance checks:**
  - After import, target week is identical to source at the roster-data level.

### 3.3b Add destructive overwrite confirmation
- **Status:** [ ]
- **Goal:** Require explicit confirmation before every import overwrite.
- **Dependencies:** 3.3a
- **Deliverables:**
  - Confirmation prompt in the roster UI before import execution.
  - Tests or documented verification for overwrite prompt behavior.
- **Acceptance checks:**
  - Import is never one-click destructive.

### 3.4 Roster page as manager/admin operations hub
- **Status:** [-]
- **Goal:** Extend the roster page into the full manager/admin operational surface with settings and a staff side panel.
- **Spec sources:** `specs/07-ui-bootstrap-spec.md`, `specs/08-ihp-implementation-spec.md`
- **Deliverables:**
  - DB Migration: Remove `shift_type_id` from `roster_slots`, add `row_index`, and make `start_time` nullable.
  - Sheet-style layout with Y-axis (Days) and grouped X-axis blocks (Early, Mid, Late), each with `Time | Staff | Code` subcolumns.
  - Manager/Admin collapsible settings bar with persistent per-user settings:
    - `show staff list`
    - live/draft checkbox
  - Desktop `70/30` roster/staff layout.
  - Mobile stacked-below staff list layout.
  - Staff list showing active linked staff only, sorted by first name, with weekly assigned shifts, ideal shifts, user role, and edit modal launcher.
  - Day controls to add/remove slot rows (`[+]` / `[-]`) using `row_index` grouping.
  - Inline editing: Staff, Start Time, and Code/Note inputs using HTMX `hx-post` for auto-save.
  - IHP AutoRefresh integration to reflect conflict badges and UI changes in real-time.
- **Acceptance checks:**
  - Manager/Admin can add rows to a day (creating 3 empty slots).
  - Manager/Admin can delete a row (removing 3 slots).
  - Changes to staff/time/notes auto-save without page refresh.
  - Manager/Admin can toggle the staff list without changing the roster width.
  - Desktop staff panel matches roster height and scrolls internally when needed.
  - Mobile staff panel renders below the roster with no internal scroll bar.
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

### 3.4a Add manager/admin roster-side staff panel layout
- **Status:** [ ]
- **Goal:** Add the responsive roster/staff split layout controlled by `show staff list`.
- **Dependencies:** 3.2b
- **Deliverables:**
  - Desktop `70/30` split with staff panel on the right.
  - Hidden-state layout where roster keeps the same width and centers.
  - Mobile stacked-below layout with no internal panel scroll.
- **Acceptance checks:**
  - Desktop panel matches the visible roster height and scrolls internally.
  - Mobile panel moves below the roster and grows naturally.

### 3.4b Populate roster-side staff list content
- **Status:** [ ]
- **Goal:** Render the manager/admin side panel with the agreed operational data.
- **Dependencies:** 3.4a
- **Deliverables:**
  - Active linked staff only.
  - Sorted by first name.
  - Per-row fields:
    - name
    - assigned shifts in the currently viewed week
    - ideal shifts
    - user role
    - edit button
- **Acceptance checks:**
  - Counts reflect the currently viewed week.
  - Trial staff do not appear.

### 3.4c Integrate roster-side staff editing entrypoint
- **Status:** [ ]
- **Goal:** Wire staff-list edit buttons to the modal workflow.
- **Dependencies:** 2.1c, 3.4b
- **Deliverables:**
  - Edit buttons launch the roster-side staff modal.
  - Save success updates both staff panel and any roster-dependent staff data.
- **Acceptance checks:**
  - Manager/admin can edit a staff member directly from the roster page.

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
- **Status:** [x]
- **Goal:** Implement leave request statuses and conflict recompute on approval.
- **Spec sources:** `specs/05-timesheets-and-leave.md`, `specs/04-roster-and-conflict-rules.md`
- **Deliverables:**
  - Leave create/review actions.
  - Validation (`end_date >= start_date`).
  - Recompute hook after approval.
- **Acceptance checks:**
  - Leave approval affects roster conflict outcomes.
- **Completion notes:**
  - Added `LeaveRequestsController` with lifecycle actions in `Web/Types.hs`, `Web/Routes.hs`, and `Web/FrontController.hs`:
    - `LeaveRequestsAction`, `NewLeaveRequestAction`, `CreateLeaveRequestAction`
    - manager review actions: `ApproveLeaveRequestAction` and `DenyLeaveRequestAction`
  - Implemented leave request flow in `Web/Controller/LeaveRequests.hs`:
    - staff submission defaults to `pending`
    - manager+ approval/denial transitions
    - explicit transaction boundaries for review transitions (`withTransaction`)
  - Added leave validation and recompute helpers in `Application/Helper/Controller.hs`:
    - `isLeaveDateRangeValid` (`end_date >= start_date`)
    - `affectedWeekOffsetsForDateRange`
    - `triggerRosterConflictRecomputeForLeave` (touches impacted `roster_weeks.updated_at` to force roster auto-refresh/recompute)
  - Added leave views:
    - `Web/View/LeaveRequests/Index.hs` (status badges + manager review buttons)
    - `Web/View/LeaveRequests/New.hs` (date range form + validation feedback)
  - Added a quick entrypoint to leave requests from `Web/View/Timesheets/Index.hs`.
  - Added tests:
    - `Test/Controller/LeaveRequestsSpec.hs` (unauthenticated redirect coverage for list/new/create/approve/deny)
    - `Test/SchemaSpec.hs` helper coverage for leave date-range validity and affected week-offset computation
    - registered in `Test/Main.hs`
  - Verification run:
    - `direnv exec . typecheck` passed
    - `direnv exec . test` passed (74 examples, 0 failures, 7 pending)
    - `direnv exec . format` passed
    - `direnv exec . lint` reports existing project warnings (including redundant-id suggestions in older files)

---

## Phase 6 — Pay Engine

### 6.1 SQL function scaffolding for canonical pay math
- **Status:** [x]
- **Goal:** Introduce SQL function interfaces for timesheet pay calculation and pay-level resolution.
- **Spec sources:** `specs/06-pay-engine.md`
- **Deliverables:**
  - SQL functions in schema/migration path.
  - Function-level tests or integration tests validating outputs.
- **Completion notes:**
  - Added canonical pay SQL scaffolding to `Application/Schema.sql`:
    - `resolve_effective_pay_level(p_staff_id, p_shift_type_id, p_day_of_week) -> uuid`
    - `calculate_timesheet_pay(p_entry_id) -> jsonb`
    - `calculate_timesheet_pay_range(p_staff_id, p_from_date, p_to_date) -> jsonb` (array payload for parser compatibility)
  - Implemented deterministic v1 JSON output contract in `calculate_timesheet_pay` with `segments` and `totals` payloads, plus a stable not-found fallback payload.
  - Added schema-level tests in `Test/SchemaSpec.hs` asserting:
    - all three SQL function signatures are present,
    - pay JSON contract keys (`segments`, `totals`, `paidMinutes`, `totalAmount`) are present,
    - range function delegates to `calculate_timesheet_pay` for canonical per-entry payloads.
  - Verification run: `regen-types`, `typecheck`, `test`, and `format` passed; `lint` reports existing project warnings.

### 6.2 Pay segmentation and weekday windows
- **Status:** [x]
- **Goal:** Implement ordinary/evening/after-midnight segment calculations.
- **Spec sources:** `specs/06-pay-engine.md`
- **Deliverables:**
  - Deterministic segment breakdown logic.
  - Boundary tests at 07:00, 19:00, 00:00.
- **Completion notes:**
  - Replaced `calculate_timesheet_pay` whole-shift placeholder segmentation in `Application/Schema.sql` with deterministic weekday windows:
    - `after_midnight` (`00:00-07:00`)
    - `ordinary` (`07:00-19:00`)
    - `evening` (`19:00-00:00`)
  - Added break-adjusted paid-window segmentation by deriving `start_minute_of_day`, `paid_end_minute_of_day`, and overlap minutes per window (`GREATEST/LEAST`), then aggregating non-zero segments in stable window order.
  - Updated pay JSON payload construction to emit computed `segments` from the new segmentation CTE while preserving existing totals contract fields.
  - Extended `Test/SchemaSpec.hs` pay-function checks to assert:
    - explicit boundary constants for `00:00`, `07:00`, and `19:00`,
    - overlap-based segment minute calculation path,
    - non-zero-only segment emission filter.

### 6.3 Weekend multiplier with penalty stacking
- **Status:** [x]
- **Goal:** Apply weekend multipliers while stacking configured penalties.
- **Spec sources:** `specs/06-pay-engine.md`
- **Deliverables:**
  - Weekend rule implementation and tests.
  - Clear output breakdown fields proving stacked composition.
- **Completion notes:**
  - Extended `calculate_timesheet_pay` in `Application/Schema.sql` so each computed segment now carries:
    - `dayRuleMultiplier` (configured `pay_level_day_rules.multiplier` fallback `1.0`)
    - `weekendMultiplier` (`1.5` on Saturday/Sunday, else `1.0`)
    - `multiplier` as stacked product (`dayRuleMultiplier * weekendMultiplier`)
  - Implemented weekend detection via `EXTRACT(DOW)` and applied stacking per-segment so weekend composition is explicit in canonical SQL output.
  - Added schema-level assertions in `Test/SchemaSpec.hs` verifying:
    - weekend multiplier branch for DOW `0`/`6`,
    - presence of breakdown fields (`dayRuleMultiplier`, `weekendMultiplier`),
    - stacked multiplier expression in the JSON payload.

### 6.4 Haskell orchestration layer for pay outputs
- **Status:** [x]
- **Goal:** Integrate SQL pay outputs into controllers/views/report payloads.
- **Spec sources:** `specs/06-pay-engine.md`, `specs/08-ihp-implementation-spec.md`
- **Deliverables:**
  - Query helpers invoking SQL functions.
  - View-model builders and endpoint wiring.
- **Completion notes:**
  - Added `Application/Helper/Pay.hs` with Haskell orchestration utilities around canonical SQL pay functions:
    - `fetchTimesheetPay` (`calculate_timesheet_pay`)
    - `fetchTimesheetPayRange` (`calculate_timesheet_pay_range`)
    - JSON decoding for pay payloads and range payloads
    - view-model summary builders (`TimesheetPaySummary`) and entry-id keyed summary maps
  - Wired pay orchestration into `Web/Controller/Timesheets.hs` by loading pay summaries for visible entries in `TimesheetsAction`.
  - Updated `Web/View/Timesheets/Index.hs` to render a new `Pay` column showing:
    - paid time from canonical payload (`paidMinutes`)
    - segment count
    - weekend/stacked multiplier indicators from summary flags
  - Added `Test/PaySpec.hs` (registered in `Test/Main.hs`) covering:
    - single payload decoding
    - range payload decoding
    - summary flag behavior for weekend + stacked multiplier scenarios

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
