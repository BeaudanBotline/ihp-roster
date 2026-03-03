module Test.Controller.LeaveRequestsSpec where

import Config
import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime (..), secondsToDiffTime)
import Generated.Types
import IHP.ControllerPrelude
import IHP.FrameworkConfig
import IHP.HaskellSupport
import IHP.Prelude
import IHP.Test.Mocking
import Network.HTTP.Types.Status
import Test.Hspec
import Test.Support
import Web.Controller.LeaveRequests ()
import Web.FrontController ()
import Web.Routes
import Web.Types

tests :: Spec
tests = beforeAll testContext do
    describe "LeaveRequestsController" do
        it "redirects unauthenticated users from leave requests page" $ withContext do
            response <- callAction LeaveRequestsAction
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from new leave request page" $ withContext do
            response <- callAction NewLeaveRequestAction
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from create leave request action" $ withContext do
            response <- callAction CreateLeaveRequestAction
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from approve leave action" $ withContext do
            let requestId = "00000000-0000-0000-0000-000000000000" :: Id LeaveRequest
            response <- callAction ApproveLeaveRequestAction { leaveRequestId = requestId }
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from deny leave action" $ withContext do
            let requestId = "00000000-0000-0000-0000-000000000000" :: Id LeaveRequest
            response <- callAction DenyLeaveRequestAction { leaveRequestId = requestId }
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from delete leave action" $ withContext do
            let requestId = "00000000-0000-0000-0000-000000000000" :: Id LeaveRequest
            response <- callAction DeleteLeaveRequestAction { leaveRequestId = requestId }
            response `responseStatusShouldBe` status302

        it "does not touch another venue's roster weeks when approving leave" $ withContext do
            withCleanDb do
                let staleTimestamp = UTCTime (fromGregorian 2024 12 1) (secondsToDiffTime 0)
                venueA <- createVenueWithConfig "Venue A"
                venueB <- createVenueWithConfig "Venue B"
                manager <- createUserRecord "leave-manager@example.com" "staff" True
                _ <- createVenueMembershipRecord venueA manager "manager"
                staffA <- createStaffRecord venueA Nothing "Ava" "Leave"
                rosterWeekA <- createRosterWeekRecord venueA 0 False >>= updateRecord . set #updatedAt staleTimestamp
                rosterWeekB <- createRosterWeekRecord venueB 0 False >>= updateRecord . set #updatedAt staleTimestamp
                leaveRequest <- createLeaveRequestRecord venueA staffA (fromGregorian 2025 1 8) (fromGregorian 2025 1 10) "pending"

                response <- withUser manager do
                    callAction ApproveLeaveRequestAction { leaveRequestId = leaveRequest.id }

                response `responseStatusShouldBe` status302

                refreshedWeekA <- fetch rosterWeekA.id
                refreshedWeekB <- fetch rosterWeekB.id

                refreshedWeekA.updatedAt `shouldSatisfy` (> staleTimestamp)
                refreshedWeekB.updatedAt `shouldBe` staleTimestamp
