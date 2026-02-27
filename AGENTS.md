# IHP Project — Agent Guidelines

## Framework Reference (in priority order)
1. **IHP Guide** — `IHP/Guide/*.markdown` covers controllers, views, routing, forms, database, auth, HSX, validation, etc. Read the relevant guide FIRST before implementing any feature.
2. **IHP Source** — `IHP/ihp/IHP/` contains the full framework source. Use grep/find here to understand type signatures, available functions, and implementation details.
3. **Generated Types** — `build/Generated/Types.hs` contains types generated from `Application/Schema.sql`. Regenerated automatically.

## Project Structure
- `Web/Types.hs` — All controller action types and app-level types
- `Web/Routes.hs` — AutoRoute instances
- `Web/FrontController.hs` — Controller mounting and context initialization
- `Web/Controller/` — Controller implementations (import `Web.Controller.Prelude`)
- `Web/View/` — Views (import `Web.View.Prelude`, use HSX quasi-quoter `[hsx|...|]`)
- `Config/Config.hs` — App configuration
- `Application/Schema.sql` — Database schema (source of truth for models)
- `Application/Helper/` — Shared helpers for controllers and views

## Styling
- **Bootstrap 5.2.1** is included via vendor files — use Bootstrap classes in HSX
- Custom CSS goes in `static/app.css` (loaded by `Web/View/Layout.hs`)
- Custom JS goes in `static/app.js`
- The layout shell is defined in `Web/View/Layout.hs` — edit `defaultLayout` to change page structure
- Use `assetPath` for all static asset references (enables cache-busting in production)

## Key Conventions
- Every new controller needs: type in `Web/Types.hs`, AutoRoute in `Web/Routes.hs`, import+mount in `Web/FrontController.hs`, implementation in `Web/Controller/`
- Use `Web.Controller.Prelude` in controllers, `Web.View.Prelude` in views — these re-export everything needed
- HSX uses `[hsx|...|]` quasi-quotes — it's like JSX but type-checked at compile time
- Database queries use IHP's QueryBuilder, not raw SQL — see `IHP/Guide/querybuilder.markdown`
- Form handling uses IHP's form helpers — see `IHP/Guide/form.markdown`

## Verification Tools
These are devenv scripts — run them directly by name inside the devenv shell (they are on PATH automatically):

- **`typecheck`** — Fast (~2-3s) typecheck without full build. **Run after every code change** to catch errors immediately. Exit 0 = success.
- **`regen-types`** — Regenerate `build/Generated/Types.hs` after editing `Application/Schema.sql`. Always run this before `typecheck` when schema has changed.
- **`test`** — Compile and run the hspec test suite. **Add tests for every new controller** (see `Test/AGENTS.md`).
- **`lint`** — Run hlint on app sources. Provides suggestions for idiomatic Haskell.
- **`format`** — Format app sources with stylish-haskell (config in `.stylish-haskell.yaml`).
- **`ghci-app`** — Launch GHCi with the full app loaded for testing expressions interactively.
- **`new-controller NAME`** — IHP code generator that scaffolds controller, views, types, and routes. Prefer this for new CRUD controllers, then customize.
- The app runs via `devenv up` — it auto-reloads on file changes, so you can check the browser for runtime behavior.

## Adding a New Feature (e.g. a new page with database table)

1. **Schema** — Add table to `Application/Schema.sql`, then run `regen-types`
2. **Types** — Add controller type to `Web/Types.hs` (see `Web/Controller/AGENTS.md` for pattern)
3. **Routes** — Add `instance AutoRoute MyController` to `Web/Routes.hs`
4. **Controller** — Create `Web/Controller/My.hs` with action implementations
5. **Views** — Create `Web/View/My/Index.hs`, `Show.hs`, etc. (see `Web/View/AGENTS.md`)
6. **Mount** — Add `import Web.Controller.My` and `parseRoute @MyController` to `Web/FrontController.hs`
7. **Verify** — Run `typecheck` (must pass before moving on)
8. **Polish** — Run `lint`, then `format`

For simple CRUD, prefer running `new-controller NAME` to scaffold all files, then customize.

## Verification Workflow
- **After every code change**: `typecheck` (fast, ~2-3s)
- **After schema changes**: `regen-types` first, then `typecheck`
- **After adding/changing controllers**: `test` to run the test suite
- **Before committing**: `lint` then `format`

## Maintaining Agent Documentation
- Subdirectory `AGENTS.md` files exist in `Web/Controller/`, `Web/View/`, and `Application/` with detailed patterns
- When you discover a new IHP pattern, convention, or gotcha while implementing a feature, **add it to the relevant `AGENTS.md`** so future agents benefit
- Keep entries concise and actionable — show the code pattern, not lengthy explanations
- Always verify patterns against `IHP/Guide/` or `IHP/ihp/IHP/` source before documenting
