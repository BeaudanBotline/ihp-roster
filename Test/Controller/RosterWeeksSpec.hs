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

        it "redirects unauthenticated users from CopyRosterWeekAction" $ withContext do
            response <- callAction (CopyRosterWeekAction 0 1)
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from AddRosterRowAction" $ withContext do
            response <- callAction (AddRosterRowAction "11111111-1111-1111-1111-111111111111")
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from DeleteRosterRowAction" $ withContext do
            response <- callAction (DeleteRosterRowAction "11111111-1111-1111-1111-111111111111" 0)
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from UpdateRosterSlotAction" $ withContext do
            response <- callAction (UpdateRosterSlotAction "22222222-2222-2222-2222-222222222222")
            response `responseStatusShouldBe` status302

        it "staff cannot see draft weeks (treats as empty/non-existent)" $ withContext do
            pendingWith "requires real DB-backed mockContext to exercise withUser + query"

        it "manager can see draft weeks" $ withContext do
            pendingWith "requires real DB-backed mockContext to exercise withUser + query"

        it "staff can see published weeks" $ withContext do
            pendingWith "requires real DB-backed mockContext to exercise withUser + query"

        it "manager can publish a draft week" $ withContext do
            pendingWith "requires real DB-backed mockContext to exercise withUser + updateRecord"

        it "manager can copy a week and it is created as draft with copied slots" $ withContext do
            pendingWith "requires real DB-backed mockContext to exercise withUser + createRecord + copy logic"
