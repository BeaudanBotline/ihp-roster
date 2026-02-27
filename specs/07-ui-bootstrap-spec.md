# UI Specification (Bootstrap 5)

## Framework baseline

- Use Bootstrap 5.2.1 utility/component patterns.
- Use HSX server-rendered views.
- Add custom CSS only where Bootstrap primitives are insufficient.

## Page-level requirements

## Roster grid

- Responsive table/grid with clear day/slot headers.
- Fast assignment controls with filter toggles.
- Visible conflict badges with deterministic priority.
- Draft/live status indicator and publish controls for Manager/Admin.

## Timesheets

- Simple create/edit form with strict 15-minute increment validation feedback.
- Approval status badges and manager actions.

## Leave

- Request form with date-range validation hints.
- Approval/denial actions for authorized roles.

## Admin/config

- Singleton venue settings screen.
- Config tables (slot names, day names, shift types, pay levels) with active/inactive support.

## UX constraints

- Server-side validation is canonical; client-side checks are advisory.
- Role-gated actions must not be rendered when unauthorized.
- Error messages should name the exact rule violated.
