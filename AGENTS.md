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

These scripts are defined in `flake.nix` as devenv shell scripts. They are placed on `PATH` automatically when the **direnv environment is active** (i.e. when a user's shell has been loaded by direnv via the `.envrc` file using `use flake`).

**Agent/automation note:** Agents and CI running outside an interactive direnv shell must prefix commands with `direnv exec .` to run them inside the activated environment:

```bash
# Correct — works from any shell (e.g. Bash tool, CI)
direnv exec . regen-types
direnv exec . typecheck
direnv exec . test
direnv exec . lint
direnv exec . format
direnv exec . e2e
direnv exec . screenshot http://localhost:8000/MyPage output.png
direnv exec . e2e-report
```

Never use bare names like `regen-types` or `typecheck` in Bash tool calls — they will fail with "command not found" unless direnv has already activated the environment in that shell session.

If you hit `attempt to write a readonly database` for nix fetcher cache, ensure `XDG_CACHE_HOME` points to a writable path (this repo defaults to `/tmp/nix-cache` in `.envrc` and `dev-start`).

Available scripts:

- **`typecheck`** — Fast (~2-3s) typecheck without full build. **Run after every code change** to catch errors immediately. Exit 0 = success.
- **`regen-types`** — Regenerate `build/Generated/Types.hs` after editing `Application/Schema.sql`. Always run this before `typecheck` when schema has changed.
- **`test`** — Compile and run the hspec test suite. **Add tests for every new controller** (see `Test/AGENTS.md`).
- **`lint`** — Run hlint on app sources. Provides suggestions for idiomatic Haskell.
- **`format`** — Format app sources with stylish-haskell (config in `.stylish-haskell.yaml`).
- **`ghci-app`** — Launch GHCi with the full app loaded for testing expressions interactively.
- **`new-controller NAME`** — IHP code generator that scaffolds controller, views, types, and routes. Prefer this for new CRUD controllers, then customize.
- **`e2e`** — Run Playwright end-to-end tests against the live dev server. Accepts playwright args (e.g. `e2e --headed`, `e2e e2e/auth.spec.ts`). Requires `devenv up` running.
- **`screenshot`** — Take a screenshot of a page. Usage: `screenshot http://localhost:8000/Dashboard dash.png`. Requires `devenv up` running.
- **`e2e-report`** — Open the Playwright HTML test report from the last run.
- **`dev-start`** — Start the IHP `start` script in background for automation (no PTY dependency). Writes pid/log to `.devenv/agent/` and fails fast if startup exits early.
- **`dev-stop`** — Stop background server started by `dev-start`. If the app is healthy but was started outside `dev-start`, it reports `healthy but unmanaged` and does not kill it.
- **`dev-status`** — Health check for background dev server (process/socket + DB + HTTP). In restricted sandboxes it may report `*_blocked=true` and still succeed when the process is running.
- **`dev-wait [seconds]`** — Wait until `dev-status` is healthy (default timeout: 90s). On timeout it prints `dev-status` plus recent `.devenv/agent/devenv.log` lines for debugging.
- The app runs via `devenv up` — it auto-reloads on file changes, so you can check the browser for runtime behavior.

For reliable non-interactive automation, prefer:

```bash
direnv exec . dev-start
direnv exec . dev-wait
# run commands that need server + DB
direnv exec . dev-stop
```

## Adding a New Feature (e.g. a new page with database table)

1. **Schema** — Add table to `Application/Schema.sql`, then:
   - Run `direnv exec . regen-types` to regenerate Haskell types
   - Run `make db` (requires `devenv up` running) to apply the schema to the dev database — **skipping this causes "relation does not exist" crashes at runtime even when typecheck passes**
2. **Types** — Add controller type to `Web/Types.hs` (see `Web/Controller/AGENTS.md` for pattern)
3. **Routes** — Add `instance AutoRoute MyController` to `Web/Routes.hs`
4. **Controller** — Create `Web/Controller/My.hs` with action implementations
5. **Views** — Create `Web/View/My/Index.hs`, `Show.hs`, etc. (see `Web/View/AGENTS.md`)
6. **Mount** — Add `import Web.Controller.My` and `parseRoute @MyController` to `Web/FrontController.hs`
7. **Verify** — Run `direnv exec . typecheck` (must pass before moving on)
8. **DB check** — Confirm the table exists: `psql -h "$PWD/build/db" app -c "\dt"`
9. **Polish** — Run `direnv exec . lint`, then `direnv exec . format`

For simple CRUD, prefer running `new-controller NAME` to scaffold all files, then customize.

## Verification Workflow
- **After every code change**: `direnv exec . typecheck` (fast, ~2-3s)
- **After schema changes**: `direnv exec . regen-types` first, then `direnv exec . typecheck`, then `make db` (requires `devenv up`)
- **After adding/changing controllers**: `direnv exec . test` to run the test suite
- **After UI/integration changes**: `direnv exec . e2e` to run end-to-end tests (requires `devenv up`)
- **Before committing**: `direnv exec . lint` then `direnv exec . format`
- **To confirm DB is in sync**: `psql -h "$PWD/build/db" app -c "\dt"` — all tables in `Schema.sql` should be present

## E2E Testing

Playwright-based end-to-end tests live in `e2e/` and run against the live dev server (`http://localhost:8000`). See `e2e/AGENTS.md` for the full guide.

- **Config**: `playwright.config.ts` — single chromium project, serial execution
- **Test data**: Seeded via `e2e/fixtures/seed.sql` (test user: `e2e-test@example.com` / `test-password-123`)
- **Cleanup**: `global-teardown.ts` deletes all rows with `e2e-` prefixed emails
- **Browsers**: Provided by Nix via `playwright-web-flake` — no manual browser install needed
- **npm deps**: `@playwright/test` version in `package.json` must match the `playwright-web-flake` tag in `flake.nix`

## Maintaining Agent Documentation
- Subdirectory `AGENTS.md` files exist in `Web/Controller/`, `Web/View/`, and `Application/` with detailed patterns
- When you discover a new IHP pattern, convention, or gotcha while implementing a feature, **add it to the relevant `AGENTS.md`** so future agents benefit
- Keep entries concise and actionable — show the code pattern, not lengthy explanations
- Always verify patterns against `IHP/Guide/` or `IHP/ihp/IHP/` source before documenting
