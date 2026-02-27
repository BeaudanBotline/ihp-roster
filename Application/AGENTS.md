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

1. **Regenerate Haskell types** — run `direnv exec . regen-types` (updates `build/Generated/Types.hs`)
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
