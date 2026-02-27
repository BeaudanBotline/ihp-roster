# Timesheets and Leave

## Timesheet entry rules

- Start/end/break inputs must be exact **15-minute increments**.
- Non-conforming inputs are rejected with explicit validation errors.
- Shift duration caps and sanity checks apply (e.g. max duration, break <= shift duration).

## Timesheet edit windows

- Staff edits are restricted to configured operational window.
- Managers/Admins may bypass staff window restrictions.

## Approval state machine

- Initial state: unapproved.
- Manager/Admin can approve.
- If staff edits an approved entry, entry automatically resets to unapproved.

## Leave lifecycle

- Staff submits leave request (`pending`).
- Admin/authorized reviewer approves or denies.
- Validation: `end_date >= start_date`.

## Leave and roster integration

- On leave approval, roster conflict signals for affected date range must be recalculated.
