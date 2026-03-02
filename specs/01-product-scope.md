# Product Scope

## Purpose

Build a venue-level rostering and timesheet system for hospitality teams, with deterministic pay calculations and manager/admin operational controls.

## Deployment model

- Single-venue deployment per instance (no cross-venue multi-tenancy in v1).
- Configuration is stored in DB and editable by authorized users.

## Core modules in scope

1. Authentication and profile onboarding.
2. Role-based access (Staff, Manager, Admin).
3. Roster planning, publication, and manager roster-side staff management.
4. Conflict detection on roster assignments.
5. Timesheet entry and approval flow.
6. Leave request and approval flow.
7. Pay calculation engine and wage summaries.
8. Admin configuration screens.

## Out of scope (v1)

- Kitchen-flag behavior.
- Trial staff conversion to login users.
- Multi-venue support.
- Full payroll export integrations (can be added later).

## Temporal model requirement

All roster scheduling logic is based on offset integers:

- `week_offset` (int, from global fixed epoch)
- `day_offset` (0..6)

Native dates can be derived for display/reporting, but offsets are canonical for planning data.

## Main operational surface

- The roster week page is the primary operational page of the app.
- There is no separate dashboard workflow.
- Manager/Admin roster work happens directly from the roster page, including week editing and staff-side management affordances.
