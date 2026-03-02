# Domain Model

## Core entities

## Tenancy and identity

- `tenants`
  - Customer business account and top-level data ownership boundary.
  - Holds tenant lifecycle, status and top-level settings.
- `users`
  - Global auth identity.
  - May belong to one or more tenants over time.
- `tenant_memberships`
  - Links a `user` to a `tenant`.
  - Holds tenant-scoped role and membership lifecycle.

## Worker records

- `staff`
  - Tenant-scoped worker profile used by roster, timesheet and pay logic.
  - May reference a `user_id` for login-enabled workers.
  - May exist without `user_id` for placeholders.
  - Must not become a dumping ground for sensitive or unrestricted free-text data.

## Governance and audit

- `audit_events`
  - Immutable audit trail for security-sensitive and employment-record actions.
  - Includes actor, tenant, event type, timestamp, target record and before/after metadata.
- `export_jobs`
  - Tenant-scoped record of generated exports, scope, file metadata, requestor and lifecycle.
- `record_corrections` or equivalent event/version tables
  - Additive correction history for payroll-adjacent records.

## Scheduling

- `roster_weeks`
  - Tenant-scoped `week_offset`
  - `is_live` (published visibility gate)
- `roster_days`
  - `roster_week_id`
  - `day_offset` (0..6)
- `roster_slots`
  - `roster_day_id`
  - `row_index` (int, groups Early/Mid/Late slots onto a single visual row)
  - Slot metadata: `start_time` (optional until manager fills it; end times are captured in timesheets) and `note` (short free-text codes like "M", "DEL").
  - Underlying backend categorizations: `slot_name_id`.
  - Assigned `staff_id`.

## Time and approval

- `timesheet_entries`
  - Staff, tenant, date/day reference, start/end/break, approval status.
  - Inputs must be exact 15-minute increments.
  - Must support additive correction or version history.
  - Hard deletion is not the normal correction path once business use begins.

## Leave and availability

- `leave_requests`
  - Staff, start/end dates, status (`pending | approved | denied`).
  - Must support status history and actor attribution.
- `staff_availability`
  - Recurring and/or date-specific preferences and restrictions.
  - Generic notes should remain operationally narrow.

## Configuration

- `tenant_config` or equivalent tenant-scoped configuration
  - Timezone.
  - Week start/day naming preferences.
  - `week_offset_epoch` (global fixed epoch value unless later re-specified).
  - `late_to_early_min_start_gap_minutes` (tenant-level threshold).
- Supporting config tables:
  - `slot_names`
  - `day_names`
  - `shift_types`
  - `pay_levels`
  - `pay_level_day_rules`

## Data classification requirements

- Ordinary profile data, payroll-adjacent data, security/audit data and restricted future data must be modelled distinctly.
- Sensitive categories such as health, banking, TFN, superannuation, biometrics or government identifiers require dedicated tables and a separate spec before introduction.
- Free-text note fields must be narrowly defined and export-reviewed.

## Data integrity requirements

- Soft-delete or active/inactive flags for config that may be referenced historically.
- Historical timesheet/pay rows must remain calculable even if config entries are disabled later.
- All tenant-owned records must be tenant-scoped at the schema level.
- Employment-record changes must preserve provenance, including actor and timestamp.
- Export generation must produce a durable audit trail and versioned output metadata.
