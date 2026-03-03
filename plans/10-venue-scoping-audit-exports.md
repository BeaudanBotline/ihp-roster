# Pipeline 10 — Venue Scoping, Audit, Exports

Read after `IMPLEMENTATION_PLAN.md` and `plans/00-auth-bootstrap-memberships.md`.

## Goal

Enforce venue-scoped data access everywhere, then add the audit and export primitives that depend on those boundaries.

## Scope

- venue-scoped query enforcement
- venue-owned config assumptions
- audit event foundations
- export job infrastructure
- venue isolation tests

## Dependencies

- depends on current venue membership resolution from pipeline 00

## Slices

### A.1 Venue schema and membership model
- **Status:** [x]
- **Goal:** Introduce venue ownership before any further product expansion.
- **Completion notes:**
  - `venues` and `venue_memberships` tables exist.
  - Venue-owned tables now carry `venue_id`.
  - Venue-scoped indexes and fixture wiring are in place.

### A.4 Venue-scope all core business queries
- **Status:** [ ]
- **Goal:** Remove global-data assumptions from controllers and helpers.
- **Deliverables:**
  - Add venue filters to roster, timesheet, leave, profile and staff queries.
  - Refactor singleton config assumptions where venue ownership is required.
  - Add helper functions for common venue-scoped query patterns.
- **Acceptance checks:**
  - No authenticated business flow can read or write another venue’s data.
  - Venue-scoped tests exist for roster, leave and timesheet flows.

### A.5 Audit-event infrastructure for sensitive actions
- **Status:** [ ]
- **Goal:** Add durable auditability before exports and broader commercial use.
- **Deliverables:**
  - Add `audit_events` schema.
  - Add shared audit write helper/service.
  - Emit events for approvals, role changes, exports and support-sensitive actions.
- **Acceptance checks:**
  - Sensitive actions create attributable audit records with venue and actor information.
  - Audit writes participate in the same transaction as business actions where feasible.

### A.8 Export job foundations
- **Status:** [ ]
- **Goal:** Treat exports as controlled disclosures before exposing them to customers.
- **Deliverables:**
  - Add `export_jobs` schema.
  - Add export service abstraction and scoped export metadata.
  - Add audit coverage for export generation and download.
- **Acceptance checks:**
  - Exports are attributable to venue, actor and scope.
  - Export lifecycle is explicit rather than ad hoc controller output.

### 1.3 Update tests for venue isolation
- **Status:** [ ]
- **Goal:** Prove that cross-venue access is blocked.
- **Deliverables:**
  - Controller tests for unauthorized cross-venue access.
  - Visibility tests for roster, timesheet and leave data.
  - Tests proving `users` fields cannot bypass venue membership checks.

## Primary Files

- `Application/Schema.sql`
- `Application/Helper/Controller.hs`
- `Application/Helper/Conflict.hs`
- `Application/Helper/Pay.hs`
- `Web/Controller/RosterWeeks.hs`
- `Web/Controller/Timesheets.hs`
- `Web/Controller/LeaveRequests.hs`
- `Web/Controller/Profiles.hs`
- `Web/Controller/Staff.hs`
- future export controllers and tests
