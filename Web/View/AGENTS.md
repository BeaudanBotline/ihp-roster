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

## Reusable Time Picker Pattern
- Use a shared modal + JS behavior for quarter-hour time selection instead of native `<input type="time">` in dense grids.
- Markup contract:
  - wrap field with `data-time-picker-field`
  - store canonical value in hidden `.js-time-picker-input` (`HH:MM` 24-hour)
  - open picker via `.js-time-picker-trigger`
  - render text in `.js-time-picker-label` (12-hour with AM/PM)
- Include `renderQuarterHourTimePickerModal` once on pages that need the picker.
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
