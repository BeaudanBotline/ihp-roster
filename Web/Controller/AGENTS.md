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
