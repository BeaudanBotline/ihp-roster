# Domain Model

## Core entities

## Users and staff

- `users`
  - Auth identity.
  - Role: `staff | manager | admin`.
  - Activation gates based on profile completion.
- `staff`
  - Employment/profile data used by roster/timesheet/pay logic.
  - Can reference a `user_id` for login-enabled staff.
  - Can exist without `user_id` for trial placeholders.

## Scheduling

- `roster_weeks`
  - `week_offset` (unique)
  - `is_live` (published visibility gate)
- `roster_days`
  - `roster_week_id`
  - `day_offset` (0..6)
- `roster_slots`
  - `roster_day_id`
  - Slot metadata: `start_time` (roster explicitly tracks only start times, end times are captured in timesheets) and `note` (short free-text codes like "M", "DEL").
  - Underlying backend categorizations: `slot_name_id`, `shift_type_id`.
  - Assigned `staff_id`.

## Time and approval

- `timesheet_entries`
  - Staff, date/day reference, start/end/break, approval status.
  - Inputs must be exact 15-minute increments.

## Leave and availability

- `leave_requests`
  - Staff, start/end dates, status (`pending | approved | denied`).
- `staff_availability`
  - Recurring and/or date-specific preferences and restrictions.

## Configuration

- `venue_config` (singleton row)
  - Timezone.
  - Week start/day naming preferences.
  - `week_offset_epoch` (global fixed epoch value).
  - `late_to_early_min_start_gap_minutes` (global threshold).
- Supporting config tables:
  - `slot_names`
  - `day_names`
  - `shift_types`
  - `pay_levels`
  - `pay_level_day_rules`

## Data integrity requirements

- Soft-delete or active/inactive flags for config that may be referenced historically.
- Historical timesheet/pay rows must remain calculable even if config entries are disabled later.
