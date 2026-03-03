# Timesheets and Leave

## Timesheet entry rules

- Start/end/break inputs must be exact **15-minute increments**.
- Non-conforming inputs are rejected with explicit validation errors.
- Shift duration caps and sanity checks apply (e.g. max duration, break <= shift duration).
- UI should reuse the shared quarter-hour modal time picker component (same as roster), while persisting canonical local wall-clock values as `HH:MM` for time-only fields.

## Timesheet edit windows

- Staff edits are restricted to configured operational window.
- Managers, Venue Admins and Venue Owners may bypass staff window restrictions.

## Approval state machine

- Initial state: unapproved.
- Manager, Venue Admin or Venue Owner can approve.
- If staff edits an approved entry, entry automatically resets to unapproved.
- Once a timesheet is in business use, corrections must be additive or versioned rather than silent destructive overwrite.
- Approval, unapproval and correction actions must preserve actor attribution and timestamps.
- Approval binds the timesheet to the pay/config snapshot version used for the calculation.

## Leave lifecycle

- Staff submits leave request (`pending`).
- Venue Admin, Venue Owner or other authorized reviewer approves or denies.
- Validation: `end_date >= start_date`.
- Leave status changes must create attributable history rather than replacing prior state with no record.
- Destructive deletion is not the normal lifecycle for leave that has already been reviewed or relied on operationally.

## Leave and roster integration

- On leave approval, roster conflict signals for affected date range must be recalculated.
- Leave approval, denial and correction actions should be auditable in the same transaction where feasible.
