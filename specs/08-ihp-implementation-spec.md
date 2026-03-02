# IHP Implementation Specification

## Ordered implementation plan

The implementation order below is intentional. It prioritises decisions that become expensive to unwind once customer data exists.

The first milestone to implement now is the SaaS pivot foundation:

1. tenant schema and membership model
2. current tenant resolution and tenant-scoped auth helpers
3. removal of bootstrap-admin and public-signup assumptions
4. tenant-scoping of all core business queries

Do not treat this as optional future hardening. It is the new prerequisite for continued feature work.

### Phase 1: foundations before broader feature expansion

1. Introduce tenant entities and tenant-scoped authorisation across the application.
2. Replace bootstrap-admin behavior with controlled tenant owner/admin bootstrap.
3. Add audit/event infrastructure for:
   - role changes,
   - timesheet approval and correction,
   - leave approval and status changes,
   - export generation and download,
   - security-sensitive access.
4. Define correction-safe handling for payroll-adjacent records:
   - additive corrections,
   - versioning, or
   - immutable event sourcing with derived current state.
5. Add export job infrastructure and file lifecycle metadata even before deep integrations.

### Phase 2: security and governance baseline before first clients

1. Harden sessions, auth and privileged action controls.
2. Add security headers and dependency review standards.
3. Introduce privacy-governance artifacts into product and ops flows:
   - privacy policy,
   - collection notices,
   - subprocessor register,
   - retention schedule,
   - breach response plan.
4. Build internal admin tooling for data access, correction and audit review.

### Phase 3: commercial readiness and controlled disclosure features

1. Add employer-mediated export workflows.
2. Add signed, expiring export download handling with audit logs.
3. Add support tooling with explicit access workflow and logging.
4. Defer direct accountant roles and advanced integrations until tenancy, audit and export governance are stable.

### Delivery posture

For the first 1 to 5 venues, optimise implementation for:

- manual customer onboarding,
- founder-managed support,
- limited but clear tenant administration,
- low operational complexity,
- no need for self-serve tenant acquisition flows.

## Required integration points

## Schema

- Define entities in `Application/Schema.sql` using IHP conventions.
- Regenerate generated types after schema changes.
- Add first-class tenant ownership fields to tenant-owned records.
- Plan dedicated tables for audit events, export jobs and record correction/version history.
- Do not add sensitive future data directly to `users` or `staff` without a dedicated spec.

## Controllers

Expected controller areas (exact naming can vary):

- Auth/Profile controller(s)
- Tenant bootstrap / membership controller(s)
- Roster controller(s) as the primary operational entrypoint
- Timesheet controller(s)
- Leave controller(s)
- Admin/Config controller(s)
- Reporting controller(s)
- Export controller(s)
- Audit / compliance admin controller(s) as needed
- Support / internal operations controller(s) as needed for managed-service workflows

Each new controller requires:

1. Type in `Web/Types.hs`.
2. `AutoRoute` in `Web/Routes.hs`.
3. Mounting in `Web/FrontController.hs`.
4. Implementation in `Web/Controller/*`.

## Views

- HSX views under `Web/View/*`.
- Layout integration through `Web/View/Layout.hs`.
- Bootstrap classes first; custom CSS in `static/app.css`.
- There is no separate dashboard workflow; the roster week view is the main post-login operational surface.
- Roster grid rendering should support a dense sheet-style table:
  - Day/date column with day-level row grouping.
  - Header with grouped blocks (`Early`, `Mid`, `Late`) and per-block subcolumns (`time/staff/note`).
  - Each visual row maps to a shared `row_index` across the three blocks.
  - Compact spacing tuned for desktop data entry and print-like readability.
  - Left day cell rendered once per day-group (visually spanning the day's rows) with row add/remove controls.
  - HTMX edits must submit full cell payload so single-field edits do not clear sibling fields.
  - Start-time editing must use a reusable modal quarter-hour picker component:
    - hidden input stores canonical `HH:MM` (24-hour) value
    - visible label shows `h:mm AM/PM`
    - selectable range is `06:00` to `23:45` in 15-minute increments
    - UI interactions dispatch `change` on the hidden input so existing HTMX autosave remains unchanged
    - component is shared for future timesheet forms
- The roster page must support a Manager/Admin-only right-side staff panel on large screens and a stacked-below layout on smaller screens.
- The roster page must expose a collapsible settings bar for Manager/Admin settings such as `show staff list` and live/draft state.
- Staff users navigating to unpublished weeks should receive a clear "not published yet" state instead of editable roster controls.

## Helpers and services

- Shared business helpers in `Application/Helper/*` where appropriate.
- Keep permission checks explicit in controller actions.
- Keep pay math canonical in SQL functions and call from controllers/helpers.
- Centralise tenant lookup and tenant authorisation guards instead of scattering ad hoc tenant checks.
- Centralise audit-event emission for security-sensitive actions.
- Centralise export generation and signed file lifecycle handling.

## Realtime considerations

- Roster/timesheet UX utilizes HTMX and IHP AutoRefresh.
- **HTMX** is used for inline mutation (e.g. `hx-post` on slot inputs) to update the server without page reloads.
- **AutoRefresh** provides the reactivity: when the database updates, IHP pushes the rendered HTML changes to the client, instantly reflecting updated states and recalculating conflict badges.
- Realtime updates are an optimization layer; canonical state transitions remain server-side.

## Data consistency

- Publishing roster and approving leave/timesheets must happen in safe transaction boundaries when side-effect recalculations are required.
- Audit/event writes should participate in the same transaction as the business action where feasible.
- Export snapshots must be generated from a defined data scope and schema version.
- Record corrections must preserve historical traceability rather than overwriting history silently.
