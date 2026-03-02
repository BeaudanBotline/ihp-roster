# Controller Guidelines

## Reference
Read `IHP/Guide/controller.markdown` before implementing any controller logic.

## Creating a New Controller

Every controller requires changes in **four files** (missing any will cause compile errors):

1. **`Web/Types.hs`** — Define the controller type:
   ```haskell
   data PostsController
       = PostsAction
       | NewPostAction
       | ShowPostAction { postId :: !(Id Post) }
       | CreatePostAction
       | EditPostAction { postId :: !(Id Post) }
       | UpdatePostAction { postId :: !(Id Post) }
       | DeletePostAction { postId :: !(Id Post) }
       deriving (Eq, Show, Data)
   ```

2. **`Web/Routes.hs`** — Add AutoRoute:
   ```haskell
   instance AutoRoute PostsController
   ```

3. **`Web/FrontController.hs`** — Mount the controller (add import + parseRoute):
   ```haskell
   import Web.Controller.Posts
   -- ...
   instance FrontController WebApplication where
       controllers =
           [ startPage WelcomeAction
           , parseRoute @PostsController
           ]
   ```

4. **`Web/Controller/Posts.hs`** — Implement actions:
   ```haskell
   module Web.Controller.Posts where
   import Web.Controller.Prelude

   instance Controller PostsController where
       action PostsAction = do
           posts <- query @Post |> fetch
           render IndexView { .. }
       action NewPostAction = do
           let post = newRecord
           render NewView { .. }
       action CreatePostAction = do
           let post = newRecord @Post
           post
               |> buildPost
               |> ifValid \case
                   Left post -> render NewView { .. }
                   Right post -> do
                       post <- post |> createRecord
                       redirectTo PostsAction
   ```

## Common Patterns

- Always import `Web.Controller.Prelude` — it re-exports everything needed
- Use `param @Type "name"` to read request parameters
- Use `fetch`, `fetchOne`, `fetchOneOrNothing` to run queries
- Use `redirectTo SomeAction` after mutations
- Use `render ViewName { .. }` with RecordWildCards to pass data to views
- Use `buildPost` pattern for form validation (see `IHP/Guide/validation.markdown`)
- Access current user with `currentUser` (requires auth setup)

## Navigation Controller Pattern
- Keep `RosterWeeksAction` as the canonical "this week" redirect endpoint.
- Week navigation should remain URL-driven via `ShowRosterWeekAction { weekOffset }`.
- When a page supports HTMX week-shell swaps, keep the same canonical routes and branch inside the action: full `render` for normal requests, `respondHtml` fragment for HTMX requests.
- If an HTMX request hits a redirect-style reset action such as `RosterWeeksAction`, prefer returning the target fragment and set `HX-Push-Url` to the canonical `Show...Action` path instead of relying on an AJAX redirect.
- For planned modules (e.g. timesheets/admin), scaffold lightweight placeholder controllers/views/routes early so header links are always valid.

## State Transition Pattern
- For status transitions with side effects (e.g. leave approval triggering roster conflict refresh), wrap the update + side-effect hook in `withTransaction` so both commit atomically.

## Overlay Controller Pattern
- Prefer dedicated HTMX dialog-fragment actions for in-place workflows instead of `setModal` + page jump.
- Recommended shape:
  - GET dialog action reads `weekOffset` or other context params and `respondHtml` with dialog fragment only
  - POST/PATCH dialog submit action re-renders the dialog fragment on validation failure
  - successful submit returns only the updated page fragment(s) needed by the current screen plus any out-of-band dialog or toast updates
- Keep `setModal` only as an explicit fallback when a workflow truly needs non-HTMX behavior.
- Reuse the same form/view helper for initial dialog render and validation rerender so field errors stay localized to the shared dialog mount.
- If a workflow mutates roster or timesheet data, return the smallest updated fragment possible (`#roster-content`, row OOB fragments, or a single day section), not a full page redirect.
- Only one workflow dialog should be active at a time. Utility pickers are a separate overlay lane and must not reuse the workflow dialog mount.
