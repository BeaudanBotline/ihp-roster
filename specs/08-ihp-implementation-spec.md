# IHP Implementation Specification

## Required integration points

## Schema

- Define entities in `Application/Schema.sql` using IHP conventions.
- Regenerate generated types after schema changes.

## Controllers

Expected controller areas (exact naming can vary):

- Auth/Profile controller(s)
- Roster controller(s)
- Timesheet controller(s)
- Leave controller(s)
- Admin/Config controller(s)
- Reporting controller(s)

Each new controller requires:

1. Type in `Web/Types.hs`.
2. `AutoRoute` in `Web/Routes.hs`.
3. Mounting in `Web/FrontController.hs`.
4. Implementation in `Web/Controller/*`.

## Views

- HSX views under `Web/View/*`.
- Layout integration through `Web/View/Layout.hs`.
- Bootstrap classes first; custom CSS in `static/app.css`.

## Helpers and services

- Shared business helpers in `Application/Helper/*` where appropriate.
- Keep permission checks explicit in controller actions.
- Keep pay math canonical in SQL functions and call from controllers/helpers.

## Realtime considerations

- Roster/timesheet UX utilizes HTMX and IHP AutoRefresh.
- **HTMX** is used for inline mutation (e.g. `hx-post` on slot inputs) to update the server without page reloads.
- **AutoRefresh** provides the reactivity: when the database updates, IHP pushes the rendered HTML changes to the client, instantly reflecting updated states and recalculating conflict badges.
- Realtime updates are an optimization layer; canonical state transitions remain server-side.

## Data consistency

- Publishing roster and approving leave/timesheets must happen in safe transaction boundaries when side-effect recalculations are required.
