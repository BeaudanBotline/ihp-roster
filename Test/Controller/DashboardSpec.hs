module Test.Controller.DashboardSpec where

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
import Web.Controller.Dashboard ()
import Web.FrontController ()
import Network.Wai
import IHP.ControllerPrelude

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
