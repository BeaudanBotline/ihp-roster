# Application Guidelines

## Schema (`Application/Schema.sql`)
This is the **source of truth** for all database models. Read `IHP/Guide/database.markdown`.

- Edit this file to add/modify tables — IHP auto-generates `build/Generated/Types.hs` from it
- Use `snake_case` for table and column names — IHP converts to `camelCase` in Haskell
- Table names should be **plural** (e.g., `posts`, `users`, `comments`)
- Always include `id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL` as first column
- Use `created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL` and `updated_at` for timestamps
- Foreign keys: `user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE`

Example:
```sql
CREATE TABLE posts (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);
```

After editing the schema you must do **two things**:

1. **Regenerate Haskell types** — run `bash ./bin/in-env regen-types` (updates `build/Generated/Types.hs`)
2. **Apply to the running database** — run `make db` while `devenv up` is active in another terminal

`make db` drops and recreates the entire database from `Schema.sql` + `Fixtures.sql`. This is safe in development. **Without running `make db` the app will crash at runtime with "relation does not exist"** even if typecheck passes.

To verify the schema is applied, connect to the dev DB and check:
```bash
psql -h "$PWD/build/db" app -c "\dt"
```

## Helpers
- `Application/Helper/Controller.hs` — Functions available in all controllers
- `Application/Helper/View.hs` — Functions available in all views
- These are already imported via `Web.Controller.Prelude` and `Web.View.Prelude`
- Keep durable audit writes centralized in `Application/Helper/Controller.hs`; prefer one append-only `audit_events` helper that stores structured `JSONB` payloads and call it inside the same `withTransaction` as the sensitive mutation.
- Keep export generation/download flow centralized in `Application/Helper/Export.hs`; controllers should delegate venue-scoped export creation, expiry checks, and audit emission there instead of hand-rolling ad hoc CSV endpoints.
- For request-scoped business context such as `currentVenue` / `currentVenueMembership`, resolve it once in `Web/FrontController.initContext` and store `Maybe ...` values via `putContext`; views can then read them safely with frozen-context helpers instead of re-querying.
- For payroll-adjacent mutations, append provenance rows from shared helpers instead of scattering ad hoc JSON snapshots across controllers. Timesheet corrections use `timesheet_entry_versions`; leave lifecycle transitions use `leave_request_events`; venue-role assignment/change uses `venue_membership_role_events`.
- Keep pay/config reproducibility centralized in `Application/Helper/Pay.hs`: venue-admin snapshot creation should serialize the current venue-owned config tables into `pay_config_snapshots`, and payroll-adjacent workflows should bind approved rows/exports to those immutable snapshot versions instead of trusting mutable current config.
- Keep reusable overlay helpers in `Application/Helper/View.hs`:
  - shared dialog and toast mount ids
  - declarative overlay config/button types
  - renderer helpers for workflow dialogs, `setModal` fallback footers, and toast notifications
- Keep toast host placement declarative as well. Prefer a `position` enum or class mapping in the helper layer instead of hardcoded left/right CSS in the layout.
- Prefer data/config records over passing Haskell callbacks into view builders. Server-rendered HSX stays easier to reuse when overlays are described declaratively.
- Shared form helpers should usually render only fields plus the `<form>` wrapper. Put submit/cancel controls in the overlay footer so the same form body can be used by both HTMX dialogs and `setModal` fallback views.

## Database Queries
Read `IHP/Guide/querybuilder.markdown`. Key patterns:
```haskell
-- Fetch all
posts <- query @Post |> fetch

-- With filters
posts <- query @Post
    |> filterWhere (#userId, userId)
    |> orderByDesc #createdAt
    |> fetch

-- Single record
post <- query @Post |> fetchOne
post <- query @Post |> fetchOneOrNothing

-- Create
newRecord @Post |> set #title "Hello" |> createRecord

-- Update
post |> set #title "New title" |> updateRecord

-- Delete
deleteRecord post
```
