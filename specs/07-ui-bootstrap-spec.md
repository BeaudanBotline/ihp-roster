# UI Specification (Bootstrap 5)

## Framework baseline

- Use Bootstrap 5.2.1 utility/component patterns.
- Use HSX server-rendered views.
- Add custom CSS only where Bootstrap primitives are insufficient.

## Page-level requirements

## Roster grid

- **Matrix Layout:** A high-density roster sheet inspired by a printed weekly schedule. Y-axis is days, X-axis is fixed chronological blocks: "Early", "Mid", and "Late".
- **Header Structure:** The table header uses grouped columns:
  - `Day`
  - `Early` with subheaders `Time | Staff | Code`
  - `Mid` with subheaders `Time | Staff | Code`
  - `Late` with subheaders `Time | Staff | Code`
- **Block Subcolumns:** Each block is rendered as three tight subcolumns:
  - **Start Time** (`TIME`)
  - **Staff** (`NAME`)
  - **Code/Flag** (`NOTE`) for short markers like `M`, `DEL`, `F`, `SUP`, `D`, `*AS`.
- **Start Time Picker UX:** Start time uses a modal picker (not browser-native time input) with:
  - 15-minute increments
  - options from `6:00 AM` through `11:45 PM`
  - 4 buttons per row in the option grid
  - selected value highlighted when opened
  - both `Clear time` and `Cancel` actions
  - immediate close + auto-save on selection
- **Time Display Format:** UI labels use 12-hour format with AM/PM (e.g. `6:15 AM`).
- **Day Column:** Left-most column shows compact day/date (e.g. `Tue` + `24/02`) and spans all rows for that day.
- **Day Controls:** Day header area includes `[+]` / `[-]` controls.
  - `[+]` adds a new visual row for the day (inserting an empty slot for Early, Mid, and Late sharing the same `row_index`).
  - `[-]` deletes the entire visual row (removing all Early/Mid/Late slots for that `row_index`).
- **Row Semantics:** A day can have many stacked rows; each row is one "line" on the printed-style sheet and maps to one shared `row_index`.
- **Shift Cells:** Each day-row has one slot in each block with inline controls for Start Time, Staff assignment, and Note/code.
- **Auto-save:** Shift edits use HTMX for inline save. No global "Save Week" for slot data.
- **Visual Density:** Table uses compact typography, narrow spacing, and day-group shading/separators to match paper-sheet readability.
- **Desktop Priority:** The primary target is desktop/laptop schedule-editing density. Mobile remains usable via horizontal scroll.
- **Print-readability:** The layout should remain legible when printed/exported (minimal decorative UI in print mode).
- **Conflict Rendering:** Conflict states are visualized by changing the background color of the Staff Assignment dropdown:
  - **Dark Red:** Critical conflicts (e.g., Duplicate assignment, Leave conflict, Late-to-Early).
  - **Light Pink/Red:** Advisory conflicts (e.g., Availability preference mismatch, Ideal-shift threshold).
- Draft/live status indicator and publish controls for Manager/Admin remain at the top of the grid.

## Timesheets

- Simple create/edit form with strict 15-minute increment validation feedback.
- Timesheet time selection should reuse the same modal quarter-hour picker component used by roster start-time fields.
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
