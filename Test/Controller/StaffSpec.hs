module Test.Controller.StaffSpec where

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
import Test.Support
import Web.Controller.Staff ()
import Web.FrontController ()
import Web.Routes
import Web.Types

tests :: Spec
tests = beforeAll testContext do
    describe "StaffController" do
        let sampleStaffId = Id "6f9638dc-f13c-4ed3-b4f1-a2f860532cab"
        it "redirects unauthenticated users from edit staff form" $ withContext do
            response <- callActionWithParams (EditStaffAction sampleStaffId) [("weekOffset", "7")]
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from update staff" $ withContext do
            response <- callActionWithParams (UpdateStaffAction sampleStaffId)
                [("firstName", "Test"), ("lastName", "User"), ("weekOffset", "7")]
            response `responseStatusShouldBe` status302

        it "returns a roster content patch for HTMX roster-launched staff edits" $ withContext do
            withCleanDb do
                venue <- createVenueWithConfig "Venue A"
                manager <- createUserRecord "staff-modal-manager@example.com" "staff" True
                linkedUser <- createUserRecord "staff-modal-worker@example.com" "staff" True
                _ <- createVenueMembershipRecord venue manager "manager"
                _ <- createVenueMembershipRecord venue linkedUser "worker"
                _ <- createRosterWeekRecord venue 0 False
                staff <- createStaffRecord venue (Just linkedUser) "Alpha" "Crew"

                response <- withUserAndCurrentVenue manager venue.id do
                    withRequestHeaders [("HX-Request", "true")] do
                        callActionWithParams
                            (UpdateStaffAction staff.id)
                            [ ("firstName", "Updated")
                            , ("lastName", "Crew")
                            , ("idealShiftsPerWeek", "4")
                            , ("isActive", "on")
                            , ("weekOffset", "0")
                            ]

                response `responseStatusShouldBe` status200
                response `responseBodyShouldContain` "id=\"roster-content\""
                response `responseBodyShouldContain` "hx-swap-oob=\"outerHTML\""
                response `responseBodyShouldContain` "Updated Crew"
