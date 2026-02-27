module Test.Controller.SessionsSpec where

import Config
import Generated.Types
import IHP.ControllerPrelude
import IHP.FrameworkConfig
import IHP.HaskellSupport
import IHP.Prelude
import IHP.Test.Mocking
import Network.HTTP.Types.Status
import Network.Wai
import Test.Hspec
import Web.Controller.Sessions ()
import Web.FrontController ()
import Web.Routes
import Web.Types

-- Note: CreateSessionAction and DeleteSessionAction both query the database,
-- so they cannot be tested with mockContextNoDatabase. A real test database
-- would be required to test successful login/logout flows end-to-end.

tests :: Spec
tests = beforeAll (mockContextNoDatabase WebApplication config) do
    describe "SessionsController" do
        it "renders the login form" $ withContext do
            response <- callAction NewSessionAction
            response `responseStatusShouldBe` status200
            response `responseBodyShouldContain` "Sign In"
            response `responseBodyShouldContain` "Create one"
