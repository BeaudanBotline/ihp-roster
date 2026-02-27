# Test Guidelines

## Reference
Read `IHP/Guide/testing.markdown` for full IHP testing documentation.

## Running Tests
```bash
test          # compile and run all tests
test --match "PostsController"  # run tests matching a pattern
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

- `mockContextNoDatabase` — Create a mock context without database (for static pages)
- `callAction SomeAction` — Call a controller action, returns `Response`
- `callActionWithParams SomeAction [("key", "value")]` — Call with form params
- `responseStatusShouldBe response status200` — Assert HTTP status
- `responseBodyShouldContain response "text"` — Assert body contains text
- `responseBodyShouldNotContain response "text"` — Assert body does not contain text
- `responseBody response` — Extract response body as `LBS.ByteString`
- `withUser user do ...` — Set current user for auth-protected actions

## What to Test

- **Every controller action** should have at least a status code assertion
- **Form submissions** (Create/Update) should verify redirect and side effects
- **Auth-protected actions** should test both authenticated and unauthenticated access
- **View content** — assert key content appears in the response body
