# View Guidelines

## Reference
Read `IHP/Guide/view.markdown` and `IHP/Guide/hsx.markdown` before creating views.

## Creating a View

Each view is a separate file in `Web/View/ControllerName/ActionName.hs`:

```haskell
module Web.View.Posts.Index where
import Web.View.Prelude

data IndexView = IndexView { posts :: [Post] }

instance View IndexView where
    html IndexView { .. } = [hsx|
        <h1>Posts</h1>
        {forEach posts renderPost}
    |]

renderPost :: Post -> Html
renderPost post = [hsx|
    <div>
        <h2>{post.title}</h2>
        <a href={ShowPostAction post.id}>Show</a>
    </div>
|]
```

## HSX Rules
- `[hsx|...|]` is the quasi-quoter — type-checked at compile time
- Embed Haskell expressions with `{expression}`
- Use `{forEach items renderItem}` for lists
- Action values work directly as `href` values: `href={ShowPostAction postId}`
- Conditional rendering: `{when condition [hsx|...|]}`
- HSX is strict about valid HTML — close all tags

## Forms
Read `IHP/Guide/form.markdown` for full details. Basic pattern:
```haskell
renderForm :: Post -> Html
renderForm post = formFor post [hsx|
    {textField #title}
    {textareaField #body}
    {submitButton}
|]
```

## Key Imports
- Always import `Web.View.Prelude` — it re-exports `IHP.ViewPrelude`, `Web.View.Layout`, `Generated.Types`, `Web.Types`, and `Application.Helper.View`
- Shared view helpers go in `Application/Helper/View.hs`
- Layout is defined in `Web/View/Layout.hs`

## Roster HTMX Pattern
- For high-frequency roster edits, avoid `hx-target="#roster-content"` full-fragment swaps on each input.
- Prefer row-targeted updates: set stable `<tr id=... data-roster-row="true">` IDs and return only affected rows with `hx-swap-oob="outerHTML"`.
- Keep `hx-sync` on roster inputs (e.g. `#roster-content:queue last`) to prevent out-of-order UI overwrites.
- When Turbolinks navigations replace page content that contains new `hx-*` markup, call `htmx.process(document.body)` on `turbolinks:load` so fresh controls are live without a manual refresh.

## Reusable Time Picker Pattern
- Use a shared picker overlay + JS behavior for quarter-hour time selection instead of native `<input type="time">` in dense grids.
- Markup contract:
  - wrap field with `data-time-picker-field`
  - store canonical value in hidden `.js-time-picker-input` (`HH:MM` 24-hour)
  - open picker via `.js-time-picker-trigger`
  - render text in `.js-time-picker-label` (12-hour with AM/PM)
  - optional range override per field: `data-time-picker-start="HH:MM"` + `data-time-picker-end="HH:MM"` (end may wrap past midnight)
- Render `renderQuarterHourTimePickerModal` once in the global layout so it stays in the picker lane and can open above a workflow dialog without competing for the shared dialog mount.
- Keep HTMX autosave on the hidden input (`hx-trigger="change"`), and let JS dispatch `change` after selecting/clearing a modal option.

## Theming Pattern (Dark Mode)
- The app uses a centralized token system in `static/app.css` (`:root` CSS variables) with dark mode as the default.
- Root layout sets dark mode via `<html data-bs-theme="dark">`; all new views should inherit this instead of setting per-page theme flags.
- Prefer semantic app wrappers/classes over one-off utilities:
  - page shells: `app-shell`, `app-content`, `app-page-auth`
  - surfaces: `app-panel`, `app-auth-card`, `app-panel-body`, `app-auth-body`
  - sizing/text helpers: `app-form-width`, `app-muted`
- Avoid inline `style="..."` in HSX for layout/sizing; add a reusable class in `static/app.css` instead.
- Avoid hardcoded light-mode classes (`bg-light`, `text-muted`) in new views; use semantic classes/tokens.
- For new component colors, add/consume CSS variables first, then apply them in selectors (including Bootstrap overrides).

## Global Header Pattern
- Authenticated navigation is centralized in `Web/View/Layout.hs` (`renderAppHeader`) so every signed-in page gets the same header.
- Keep nav button labels/order consistent: `roster`, `profile`, `timesheets`, `leave`, `admin`, `logout`.
- Keep `admin` link visibility role-gated (admin only) via `currentUserIsAdmin`.
- Do not duplicate primary nav in page-level views unless there is a specific workflow reason.

## Roster Week Controls
- Keep week browsing URL-driven via `weekOffset` action params.
- Use compact controls in the roster page header: `<`, `this week`, `>`.
- `this week` should link to `RosterWeeksAction` (server-side reset to current offset), not a client-side calculation.
- For HTMX week browsing, wrap the header + page content in a stable shell id, target that shell with `hx-get`, `hx-swap="outerHTML"`, `hx-select`, `hx-push-url="true"`, and `hx-sync="#shell-id:replace"`.
- Add `data-turbolinks="false"` on HTMX partial-navigation anchors so Turbolinks does not steal the click and force a full-page visit.
- For roster side-panel sizing on desktop, prefer CSS-only sticky layout with a viewport-capped panel and internal scroll over JS height syncing.

## Overlay Pattern
- Prefer HTMX-driven workflow dialog fragments over `setModal` + page-jump flows for roster, timesheets, and other high-frequency in-place workflows.
- Render top-level overlay hosts in `Web/View/Layout.hs`:
  - one shared dialog mount for workflow dialogs
  - one shared toast mount for transient notifications
  - picker markup rendered separately for utility overlays
- Default toast placement is bottom-center. Future left/right placement changes should come from shared helper config, not layout-specific markup changes.
- Keep reusable overlay helpers in `Application/Helper/View.hs` so structure, title, close behavior, and footer/button handling stay centralized.
- Dialog launch contract:
  - trigger uses `hx-get`
  - target is the shared dialog mount
  - swap is `innerHTML`
  - include `weekOffset` or other return-context params in the URL/query
- Dialog submit contract:
  - validation failure returns the dialog fragment again into the same mount
  - success returns updated page fragments plus any out-of-band dialog or toast updates, instead of redirecting the full page
- Prefer dialog footers built from shared overlay button config. Form helpers should usually not render their own save/cancel rows.
- Only allow one workflow dialog at a time. Pickers may appear above a dialog, but they are a separate overlay kind with separate JS behavior.
