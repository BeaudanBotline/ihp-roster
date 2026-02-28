# UI Specification (Bootstrap 5)

## Framework baseline

- Use Bootstrap 5.2.1 utility/component patterns.
- Use HSX server-rendered views.
- Add custom CSS only where Bootstrap primitives are insufficient.

## Page-level requirements

## Roster grid

- **Matrix Layout:** A high-density data-entry grid. The Y-axis represents Days of the week. The X-axis is divided into three fixed chronological blocks: "Early", "Mid", and "Late".
- **Day Controls:** The left-most column contains Day/Date labels, a `[ ] Closed` checkbox, and `[+]` / `[-]` controls.
  - `[+]` adds a new visual row for the day (inserting an empty slot for Early, Mid, and Late sharing the same `row_index`).
  - `[-]` deletes the entire visual row (removing all Early/Mid/Late slots for that `row_index`).
- **Shift Cells:** Each populated shift cell within a block contains:
  - A text/time input for **Start Time** (e.g., "10AM", "1PM"). End times are explicitly not recorded in the roster UI.
  - A `<select>` dropdown for **Staff Assignment**, enabling rapid reassignment.
  - A short free-text **Note** input for attaching small codes (e.g., "M", "DEL", "F", "SUP").
  - **Auto-save:** All cell inputs use HTMX to auto-save to the server on `change`. There is no global "Save Week" button for slot data.
- **Conflict Rendering:** Conflict states are visualized by changing the background color of the Staff Assignment dropdown:
  - **Dark Red:** Critical conflicts (e.g., Duplicate assignment, Leave conflict, Late-to-Early).
  - **Light Pink/Red:** Advisory conflicts (e.g., Availability preference mismatch, Ideal-shift threshold).
- Draft/live status indicator and publish controls for Manager/Admin remain at the top of the grid.

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
