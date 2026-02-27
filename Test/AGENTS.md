# Test Guidelines

## Reference
Read `IHP/Guide/testing.markdown` for full IHP testing documentation.

## Running Tests

Tests are a devenv shell script — use `direnv exec .` outside an interactive shell:

```bash
direnv exec . test                             # compile and run all tests
direnv exec . test --match "PostsController"  # run tests matching a pattern
```

## Adding Tests for a New Controller

When adding a new controller (e.g., `PostsController`), create a corresponding spec:

1. Create `Test/Controller/PostsSpec.hs`:
   ```haskell
   module Test.Controller.PostsSpec where

   import Network.HTTP.Types.Status
   import IHP.Prelude
   import IHP.Test.Mocking
   import IHP.FrameworkConfig
   import IHP.HaskellSupport
   import Test.Hspec
   import Config
   import Generated.Types
   import Web.Routes
   import Web.Types
   import Web.Controller.Posts ()
   import Web.FrontController ()
   import Network.Wai
   import IHP.ControllerPrelude

   tests :: Spec
   tests = beforeAll (mockContextNoDatabase WebApplication config) do
       describe "PostsController" do
           it "renders the index page" $ withContext do
               response <- callAction PostsAction
               response `responseStatusShouldBe` status200

           it "renders the new post form" $ withContext do
               response <- callAction NewPostAction
               response `responseStatusShouldBe` status200
               response `responseBodyShouldContain` "New Post"

           it "creates a post via form submission" $ withContext do
               response <- callActionWithParams CreatePostAction
                   [("title", "Test Post"), ("body", "Test body")]
               response `responseStatusShouldBe` status302
   ```

2. Register it in `Test/Main.hs`:
   ```haskell
   import qualified Test.Controller.PostsSpec

   main = hspec do
       Test.Controller.StaticSpec.tests
       Test.Controller.PostsSpec.tests
   ```

## Available Test Helpers (from `IHP.Test.Mocking`)

- `mockContextNoDatabase` — Create a mock context without a real DB connection (for static/form-render tests)
- `callAction SomeAction` — Call a controller action, returns `Response`
- `callActionWithParams SomeAction [("key", "value")]` — Call with form params
- `responseStatusShouldBe response status200` — Assert HTTP status
- `responseBodyShouldContain response "text"` — Assert body contains text
- `responseBodyShouldNotContain response "text"` — Assert body does not contain text
- `responseBody response` — Extract response body as `LBS.ByteString`
- `withUser user do ...` — Set current user for auth-protected actions

## `mockContextNoDatabase` Limitations

`mockContextNoDatabase` sets up a connection pool but leaves the underlying DB connection `undefined`. Any action that touches the database at runtime will return a **500**.

This means:

- **Safe to test** with `mockContextNoDatabase`: rendering forms, unauthenticated redirects (`ensureIsUser` with no session), any action that never queries the DB
- **Cannot test** with `mockContextNoDatabase`: `CreateSessionAction`/`DeleteSessionAction` (both query the DB), `withUser` + an auth-gated page (because `initAuthentication` fetches the user record from the DB by session ID, even when the session is set via `withUser`)

For tests that require a real database, a separate test database and `mockContext` with a live connection would be needed. Document these as `-- requires real DB` and skip them until a test DB is configured.

## What to Test

- **Every controller action** should have at least a status code assertion
- **Form submissions** (Create/Update) should verify redirect and side effects
- **Auth-protected actions** should test both authenticated and unauthenticated access
- **View content** — assert key content appears in the response body
