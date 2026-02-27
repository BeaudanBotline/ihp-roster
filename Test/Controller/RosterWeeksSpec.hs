module Test.Controller.RosterWeeksSpec where

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
import Web.Controller.RosterWeeks ()
import Web.FrontController ()
import Web.Routes
import Web.Types

tests :: Spec
tests = beforeAll (mockContextNoDatabase WebApplication config) do
    describe "RosterWeeksController" do
        it "redirects unauthenticated users from RosterWeeksAction" $ withContext do
            response <- callAction RosterWeeksAction
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from ShowRosterWeekAction" $ withContext do
            response <- callAction (ShowRosterWeekAction 0)
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from CreateRosterWeekAction" $ withContext do
            response <- callAction (CreateRosterWeekAction 0)
            response `responseStatusShouldBe` status302
