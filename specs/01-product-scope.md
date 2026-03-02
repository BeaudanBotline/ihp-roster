# Product Scope

## Purpose

Build a SaaS rostering, timesheet and payroll-adjacent operations system for small Australian hospitality businesses, with deterministic pay calculations, strong record integrity and venue-scoped operational controls.

## Deployment model

- Multi-venue SaaS is the target architecture from the outset, even if early pilots are operationally simple.
- Each customer business is a venue.
- A venue may initially operate a single venue, but the product must not depend on "one deployment per business" assumptions.
- Configuration is stored in DB and editable by venue-authorized users subject to audit and permission rules.
- Initial go-to-market model is local, high-touch and managed:
  - small number of local venues,
  - manual onboarding,
  - direct founder support,
  - no public self-serve growth assumptions in v1.

## Core modules in scope

1. Authentication and profile onboarding.
2. Venue, membership and role-based access control.
3. Roster planning, publication, and manager roster-side staff management.
4. Conflict detection on roster assignments.
5. Timesheet entry, approval and correction-safe record handling.
6. Leave request and approval flow.
7. Pay calculation engine and wage summaries.
8. Admin configuration screens.
9. Auditability, exportability and record retention foundations.
10. Privacy, security and compliance controls required for a customer-facing SaaS product.
11. Managed-service support workflows suitable for a small local customer base.

## Out of scope (v1)

- Kitchen-flag behavior.
- Trial staff conversion to login users.
- Full payroll processing.
- Direct accountant logins.
- Deep HR data categories such as health, banking, superannuation or tax identifiers until separately specified.
- Marketplace-style self-serve venue signup and low-touch mass onboarding.

## Temporal model requirement

All roster scheduling logic is based on offset integers:

- `week_offset` (int, from global fixed epoch)
- `day_offset` (0..6)

Native dates can be derived for display/reporting, but offsets are canonical for planning data.

## Main operational surface

- The roster week page is the primary operational page of the app.
- There is no separate dashboard workflow.
- Manager/Admin roster work happens directly from the roster page, including week editing and staff-side management affordances.

## Compliance posture

- The product is designed as APP-aligned by default rather than relying on customer exemptions.
- Payroll-adjacent and employment records must support retention, correction provenance and export integrity.
- Exports to employers, bookkeepers or accountants are treated as controlled disclosures, not simple file downloads.

## Commercial posture

- The near-term goal is a small number of local venues rather than broad scale.
- Product decisions should prefer reliability, supportability and legal clarity over self-serve growth features.
- Architecture should still preserve the option to grow beyond the first few venues without re-platforming.
