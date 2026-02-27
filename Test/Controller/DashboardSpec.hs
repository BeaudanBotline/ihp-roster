module Test.Controller.DashboardSpec where

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
import Web.Controller.Dashboard ()
import Web.FrontController ()
import Web.Routes
import Web.Types

-- Note: Testing an authenticated dashboard response requires initAuthentication
-- to fetch the user record from the database, so it cannot be tested with
-- mockContextNoDatabase. A real test database would be needed for that case.

tests :: Spec
tests = beforeAll (mockContextNoDatabase WebApplication config) do
    describe "DashboardController" do
        it "redirects unauthenticated users to the login page" $ withContext do
            -- No session set: ensureIsUser redirects to /NewSession
            response <- callAction DashboardAction
            response `responseStatusShouldBe` status302

        it "enforces profile gate for authenticated users (requires real DB-backed auth context)" $ withContext do
            pendingWith "requires real DB-backed mockContext to exercise withUser + initAuthentication"
